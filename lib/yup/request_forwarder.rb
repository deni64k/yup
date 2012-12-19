require 'em-http-request'

module Yup
  class RequestForwarder
    def initialize(http_method, request_url, headers, body, forward_to, timeout)
      @http_method = http_method
      @request_url = request_url
      @headers     = headers
      @body        = body
      @forward_to  = forward_to
      @timeout     = timeout
      @logger      = Yup.logger.clone

      @headers.merge!(
        'Host'       => @forward_to,
        'Connection' => 'Close')
    end

    def perform
      http_method = @http_method.to_sym
      http_url    = "http://#{@forward_to}#{@request_url}"
      http = EventMachine::HttpRequest.
        new(http_url,
            :inactivity_timeout => @timeout).
        send(http_method,
             :head => @headers,
             :body => @body)

      @logger.progname = "Yup::RequestForwarder (##{self.__id__.to_s(36)} received at #{Time.now.to_s})"

      http.callback do
        Yup.watermark += 1

        if http.response_header && http.response_header.status && http.response_header.status / 100 == 2
          log_response(http)
          @logger.info "Success"
        else
          log_response(http)
          if Yup.retry_unless_2xx
            @logger.info "Fail: got status code #{http.response_header.status}; will retry after #{Yup.resend_delay} seconds"
            EventMachine.add_timer(Yup.resend_delay, &self.method(:retry))
          else
            @logger.info "Fail; will not retry"
          end
        end
      end

      http.errback do
        log_response(http)
        @logger.info "Error: #{http.inspect}: #{http.error}; will retry after #{Yup.resend_delay} seconds"

        EventMachine.add_timer(Yup.resend_delay, &self.method(:retry))
      end
    end

    def retry
      self.perform
    end

  private
    def log_response(http)
      @logger.info { "HTTP request: #{@http_method.upcase} #{@request_url} HTTP/1.1" }
      if http.response_header.http_status
        @logger.info  { "HTTP response: HTTP/#{http.response_header.http_version} #{http.response_header.http_status} #{http.response_header.http_reason}" }
        @logger.debug { "HTTP response headers" + (http.response_header.empty? ? " is empty" : "\n" + http.response_header.inspect) }
        @logger.debug { "HTTP response body"    + (http.response.empty? ? " is empty" : "\n" + http.response.inspect) }
      end
    end
  end

  class State
    class RequestForwarder
      def initialize(state, forward_to, timeout)
        @state      = state
        @forward_to = forward_to
        @timeout    = timeout
        @logger     = Yup.logger.clone
        @logger.progname = "Yup::State::RequestForwarder"

        @yajl = Yajl::Parser.new(:symbolize_keys => true)
        @yajl.on_parse_complete = self.method(:make_request)
      end

      def run_loop
        loop do
          data = @state.bpop
          begin
            @yajl << data
          rescue Yajl::ParseError
            @logger.error { "Error while parsing \"#{data}\"" }
          end
        end
      end

      def make_request(req)
        begin
          @http_method, @request_url, headers, body = req
          headers = Hash[*headers.to_a.flatten.map(&:to_s)]
          headers["Host"]       = @forward_to
          headers["Connection"] = "Close"

          req = "#{@http_method.upcase} #{@request_url} HTTP/1.1\r\n"
          headers.each do |k, v|
            req << "#{k}: #{v}\r\n"
          end
          req << "\r\n"
          req << body if !body.empty?
          raw_response = send_data(req.to_s, @forward_to)

          response_body = ""
          http = Http::Parser.new()
          http.on_body = proc do |chunk|
            response_body << chunk
          end
          http << raw_response

          if http.status_code && http.status_code / 100 == 2
            log_response(raw_response, response_body, http)
            @logger.info "Success"
          else
            log_response(raw_response, response_body, http)
            if Yup.retry_unless_2xx
              @logger.info "Fail: got status code #{http.status_code}; will retry after #{Yup.resend_delay} seconds"
              @state.to_feedback(Yajl::Encoder.encode([@http_method.downcase, @request_url, headers, body]))

              sleep Yup.resend_delay
            else
              @logger.info "Fail; will not retry"
            end
          end

        rescue Exception, Timeout::Error => e
          log_response(raw_response, response_body, http)
          @logger.info "Error: #{e.class}: #{e.message}; will retry after #{Yup.resend_delay} seconds"

          @state.to_feedback(Yajl::Encoder.encode([@http_method.downcase, @request_url, headers, body]))

          sleep Yup.resend_delay
        end
      end

    private
      def log_response(raw_response, body, http)
        @logger.info { "HTTP request: #{@http_method.upcase} #{@request_url} HTTP/1.1" }
        if raw_response && !raw_response.empty?
          @logger.info  { "HTTP response: #{raw_response.lines.first.chomp}" }
          @logger.debug { "HTTP response headers" + (http.headers.empty? ? " is empty" : "\n" + http.headers.inspect) }
          @logger.debug { "HTTP response body"    + (body.empty? ? " is empty" : "\n" + body.inspect) }
        end
      end

      def send_data(data, host)
        host, port = host.split(":")
        addr = Socket.getaddrinfo(host, nil)
        sock = Socket.new(Socket.const_get(addr[0][0]), Socket::SOCK_STREAM, 0)

        secs   = Integer(@timeout)
        usecs  = Integer((@timeout - secs) * 1_000_000)
        optval = [secs, usecs].pack("l_2")
        sock.setsockopt(Socket::SOL_SOCKET, Socket::SO_RCVTIMEO, optval)
        sock.setsockopt(Socket::SOL_SOCKET, Socket::SO_SNDTIMEO, optval)

        resp = Timeout::timeout(@timeout) do
          sock.connect(Socket.pack_sockaddr_in(port, addr[0][3]))
          sock.write(data)
          sock.read()
        end
        return resp
      ensure
        sock.close()
      end
    end

    class FeedbackHandler < EM::Connection
      def initialize(state)
        @state      = state

        @yajl   = Yajl::Parser.new(:symbolize_keys => true)
        @yajl.on_parse_complete = method(:on_message)

        @logger = Yup.logger.clone
        @logger.progname = "Yup::State::FeedbackHandler"
      end

      def receive_data(data)
        begin
          @yajl << data
        rescue Yajl::ParseError
          @logger.error { "Error while parsing \"#{data}\"" }
        end
      end

      def on_message(req)
        @state.push(Yajl::Encoder.encode(req))
      end
    end
  end
end
