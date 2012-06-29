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

      @logger = Yup.logger
    end

    def run
      http_method = @http_method.to_sym
      http_url    = "http://#{@forward_to}#{@request_url}"
      http = EventMachine::HttpRequest.
        new(http_url).
        send(http_method,
             :timeout => @timeout,
             :head => @headers.merge('Host' => @forward_to),
             :body => @body)

      http.callback do
        Yup.watermark += 1

        if http.response_header.status / 100 == 2
          @logger.info '--- SUCCESS'
        else
          @logger.info '--- FAIL'
          @logger.debug { http.inspect }
          @logger.debug { http.response_header.inspect }
          @logger.debug { http.response.inspect }
        end
      end

      http.errback do
        @logger.info '--- ERROR'
        @logger.debug { http.inspect }
        @logger.debug { http.response_header.inspect }
        @logger.debug { http.response.inspect }

        EventMachine.add_timer(Yup.resend_delay) { self.run }
      end
    end
  end

  class State
    class RequestForwarder
      def initialize(state, forward_to, timeout)
        @state      = state
        @forward_to = forward_to
        @timeout = timeout

        @logger = Yup.logger
        @yajl   = Yajl::Parser.new(:symbolize_keys => true)
        @yajl.on_parse_complete = method(:make_request)
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
                 :timeout => timeout)

          if http.code_2xx?
            @logger.info '--- SUCCESS'
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
