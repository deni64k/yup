require 'webrick'
require 'http/parser'

module Yup
  class RequestHandler < EM::Connection
    attr_reader :queue

    def initialize(forward_to, status_code, state, timeout)
      @forward_to  = forward_to
      @status_code = status_code
      @state       = state
      @timeout     = timeout

      @chunks = []

      @logger = Yup.logger.clone
      @logger.progname = "Yup::RequestHandler"
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
      @logger.info  {
        "Processing a new request: #{@parser.http_method} #{@parser.request_url} HTTP/#{@parser.http_version.join('.')}"
      }
      @logger.debug {
        "HTTP headers" + (@parser.headers.empty? ? " is empty" : "\n" + @parser.headers.inspect)
      }
      @logger.debug {
        "HTTP body"    + (@body.empty? ? " is empty" : "\n" + @body)
      }

      send_answer
      shedule_request
    end

    private
    def send_answer
      @logger.info {
        peername = get_peername
        port, ip = if peername
          Socket.unpack_sockaddr_in(peername)
        else
          ["unknown", "unknown"]
        end
        "Sending the answer #{@status_code} to a client #{ip}:#{port}"
      }

      resp = WEBrick::HTTPResponse.new(:HTTPVersion => '1.1')
      resp.status = @status_code
      resp['Server'] = 'yupd'
      send_data resp.to_s
      close_connection_after_writing
    end

    def shedule_request
      if @state
        @state.push(Yajl::Encoder.encode([@parser.http_method.downcase, @parser.request_url, @parser.headers, @body, @forward_to]))
      else
        unless Yup.watermark.zero?
          Yup.watermark -= 1
          EM.next_tick do
            RequestForwarder.new(@parser.http_method.downcase, @parser.request_url, @parser.headers, @body, @forward_to, @timeout).perform
          end
        else
          @logger.error "Watermark is reached, drop the request"
        end
      end
    end
  end
end
