require 'webrick'
require 'http/parser'

module Yup
  class RequestHandler < EM::Connection
    attr_reader :queue

    def initialize(forward_to, status_code)
      @forward_to  = forward_to
      @status_code = status_code
      @chunks     = []
    end

    def post_init
      @parser = Http::Parser.new(self)
    end

    def receive_data(data)
      @parser << data
    end

    def on_message_begin
      @body = ''
    end

    def on_body(chunk)
      @body << chunk
    end

    def on_message_complete
      logger.info  "-- got request"
      logger.info  "HTTP version: "      + @parser.http_version
      logger.info  "HTTP method : "      + @parser.http_method # for requests
      logger.info  "HTTP request_url : " + @parser.request_url
      logger.debug "HTTP headers : "     + @parser.headers

      resp = WEBrick::HTTPResponse.new(:HTTPVersion => '1.1')
      resp.status = @status_code
      resp['Server'] = 'yupd'
      send_data resp.to_s

      unless Yup.watermark.zero?
        Yup.watermark -= 1

        EventMachine.next_tick do
          RequestForwarder.new(@parser, @body, @forward_to).run
        end
      else
        logger.error "-- watermark is reached, drop"
      end
    end
  end
end
