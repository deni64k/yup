require 'helper'

class Yup::RequestForwarder
  alias :retry_original :retry
  def retry()
    $attempts += 1
    retry_original()
  end
end

class TestYup < MiniTest::Unit::TestCase
  class RequestHandlerMock < Yup::RequestHandler
  end

  class Service < EM::Connection
    def post_init
      @parser = Http::Parser.new(self)
    end

    def receive_data(data)
      @parser << data
    end

    def on_message_complete
      $service_parser = @parser

      case $attempts
      when 0
      when 1
        send_data "HTTP/1.1 400 OK\r\nServer: test\r\n\r\n"
      when 2
        send_data "HTTP/1.1 200 OK\r\nServer: test\r\n\r\n"
        close_connection_after_writing
      end
    end

    def unbind
      if $attempts >= 2
        EM.next_tick { EM.stop_event_loop }
      end
    end
  end

  module Client
    def connection_completed
      send_data "GET /foo HTTP/1.0\r\n\r\n"
    end

    def post_init
      @parser = Http::Parser.new(self)
    end

    def receive_data(data)
      @parser << data
    end

    def on_message_complete
      $client_parser = @parser
    end
  end

  def test_request_handler
    $attempts = 0

    forward_to  = "127.0.0.1:16785"
    status_code = 200
    state       = nil
    timeout     = 1

    Yup.resend_delay     = 1
    Yup.retry_unless_2xx = true

    EM.run {
      EM.start_server("127.0.0.1", 16785, Service)
      EM.start_server("127.0.0.1", 16784, RequestHandlerMock, forward_to, status_code, state, timeout)
      EM.connect("127.0.0.1", 16784, Client)
    }

    assert       $client_parser
    assert_equal 200,   $client_parser.status_code
    assert_equal "yupd", $client_parser.headers["Server"]
    assert       $service_parser
    assert_equal "/foo", $service_parser.request_url
  end
end
