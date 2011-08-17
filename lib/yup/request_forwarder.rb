require 'em-http-request'

module Yup
  class RequestForwarder
    def initialize(parser, body, forward_to, logger)
      @parser     = parser
      @body       = body
      @forward_to = forward_to
      @logger = logger
    end

    def run
      http_method = @parser.http_method.downcase.to_sym
      http_url    = "http://#{@forward_to}#{@parser.request_url}"
      http = EventMachine::HttpRequest.
        new(http_url).
        send(http_method,
             :head => @parser.headers.merge('Host' => @forward_to),
             :body => @body)

      http.callback do
        Yup.watermark += 1

        if http.response_header.status / 100 == 2
          @logger.info '--- SUCCESS'
        else
          @logger.info '--- FAIL'
          # logger.debug http.response_header.inspect
          # logger.debug http.response
          @logger.debug http
        end
      end

      http.errback do
        @logger.info '--- ERROR'
        @logger.debug http

        EventMachine.add_timer(Yup.resend_delay) { self.run }
      end
    end
  end
end
