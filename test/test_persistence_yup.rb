require 'helper'

require 'tmpdir'
require 'fileutils'
require 'yup/state'

class Yup::State::FeedbackHandler
  alias :on_message_original :on_message
  def on_message(req)
    on_message_original(req)
    $attempts += 1
  end
end

class TestPersistenceYup < MiniTest::Unit::TestCase
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
        send_data "HTTP/1.1 400 Bad Request\r\nServer: test\r\n\r\n"
        close_connection_after_writing
      when 2
        send_data "HTTP/1.1 200 OK\r\nServer: test\r\n\r\n"
        close_connection_after_writing
      end
    end

    def unbind
      if $attempts >= 2
        EM.add_timer(1) do
          Process.kill("KILL", $pid)
          EM.stop_event_loop()
        end
      end
    end
  end

  module Client
    def connection_completed
      send_data("GET /foo HTTP/1.0\r\n\r\n")
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

    dbpath           = Dir.mktmpdir("yupd-db")
    feedback_channel = File.join(Dir.tmpdir, "yupd-#{$$}-feedback")

    forward_to  = "127.0.0.1:26785"
    status_code = 200
    state       = Yup::State.new(dbpath, forward_to, feedback_channel)
    timeout     = 1

    Yup.resend_delay     = 1
    Yup.retry_unless_2xx = true

    $pid = Process.fork do
      Yup::State::RequestForwarder.new(state, forward_to, timeout).run_loop
    end

    EM.run {
      EM.start_server("127.0.0.1", 26785, Service)
      EM.start_unix_domain_server(feedback_channel, Yup::State::FeedbackHandler, state)
      EM.start_server("127.0.0.1", 26784, RequestHandlerMock, forward_to, status_code, state, timeout)
      EM.connect("127.0.0.1", 26784, Client)
    }

    assert       $client_parser
    assert_equal 200,    $client_parser.status_code
    assert_equal "yupd", $client_parser.headers["Server"]
    assert       $service_parser
    assert_equal "/foo", $service_parser.request_url
  ensure
    Process.kill("KILL", $pid) if $pid
    state.close if state
    FileUtils.remove_entry_secure(dbpath) if dbpath
  end
end
