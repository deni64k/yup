require 'em-http-request'

module Yup
  class RequestForwarder
    def initialize(parser, body, forward_to)
      @parser     = parser
      @body       = body
      @forward_to = forward_to
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
        if http.response_header.status / 100 == 2
          puts '--- SUCCESS'
        else
          puts '--- FAIL'
          # puts http.response_header.inspect
          # puts http.response
          p http
        end
      end

      http.errback do
        puts '--- ERROR'
        p http

        EventMachine.add_timer(Yup.resend_delay) { self.run }
      end
    end
  end
end
