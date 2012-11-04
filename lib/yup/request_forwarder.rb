require 'em-http-request'
require 'http_request'

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
    end

    def perform
      http_method = @http_method.to_sym
      http_url    = "http://#{@forward_to}#{@request_url}"
      http = EventMachine::HttpRequest.
        new(http_url,
            :inactivity_timeout => @timeout).
        send(http_method,
             :head => @headers.merge('Host' => @forward_to),
             :body => @body)

      @logger.progname = "Yup::RequestForwarder (##{http.__id__.to_s(36)} received at #{Time.now.to_s})"

      http.callback do
        Yup.watermark += 1

        if http.response_header.status / 100 == 2
          log_response(http)
          @logger.info "Success"
        else
          log_response(http)
          @logger.info "Fail; will not retry"
        end
      end

      http.errback do
        log_response(http)
        @logger.info "Error: #{http.error}; will retry after #{Yup.resend_delay} seconds"

        EventMachine.add_timer(Yup.resend_delay, &self.method(:retry))
      end
    end

    def retry
      self.perform
    end

    def log_response(http)
      @logger.info { "HTTP request: #{@http_method.upcase} #{@request_url} HTTP/1.1" }
      if http.response_header.http_status
        @logger.info { "HTTP response: HTTP/#{http.response_header.http_version} #{http.response_header.http_status} #{http.response_header.http_reason}" }
        @logger.debug { "HTTP response headers" + (http.response_header.empty? ? " is empty" : "\n" + http.response_header.inspect) }
        @logger.debug { "HTTP response body"    + (http.response.empty? ? " is empty" : "\n" + http.response.inspect) }
      end
      # @logger.debug { "http.inspect\n" + http.inspect }
    end
  end

  class State
    class RequestForwarder
      def initialize(state, forward_to, timeout)
        @state      = state
        @forward_to = forward_to
        @timeout    = timeout
        @logger     = Yup.logger.clone

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
          http_method, request_url, headers, body = req
          headers = Hash[headers.to_a.flatten.map(&:to_s)]

          http_method = http_method.to_sym
          http_url    = "http://#{@forward_to}#{request_url}"
          http = HttpRequest.
            send(http_method,
                 :url => http_url,
                 :headers => headers.merge('Host' => @forward_to),
                 :parameters => body,
                 :inactivity_timeout => @timeout)

          if http.code_2xx?
            @logger.info "SUCCESS"
          else
            @logger.info '--- FAIL'
            @logger.debug { http.inspect }
            @logger.debug { http.response_header.inspect }
            @logger.debug { http.response.inspect }
          end
        rescue Exception => e
          @logger.info '--- ERROR'
          @logger.debug { e }

          @state.to_feedback(Yajl::Encoder.encode([http_method.downcase, request_url, headers, body]))

          sleep Yup.resend_delay
        end
      end
    end

    class FeedbackHandler < EM::Connection
      def initialize(state)
        @state      = state

        @logger = Yup.logger
        @yajl   = Yajl::Parser.new(:symbolize_keys => true)
        @yajl.on_parse_complete = method(:on_message)
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
