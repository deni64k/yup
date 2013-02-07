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
end
