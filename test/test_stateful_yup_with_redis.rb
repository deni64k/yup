require 'helper'

require 'tmpdir'
require 'fileutils'
require 'yup/state/redis'

class TestStatefulYupWithRedis < YupTestCase
  class RequestHandlerMock < Yup::RequestHandler
  end

  def test_request_handler
    uri         = "redis://localhost/yup-testing-#{Time.now.to_f}"
    forward_to  = "127.0.0.1:26785"
    status_code = 200
    state       = Yup::State::Redis.new(uri, forward_to)
    timeout     = 1

    Yup.resend_delay     = 1
    Yup.retry_unless_2xx = true

    $pid = Process.fork do
      Yup::State::Redis::RequestForwarder.new(state, forward_to, timeout).run_loop
    end

    EM.run {
      EM.start_server("127.0.0.1", 26785, Service)
      EM.start_server("127.0.0.1", 26784, RequestHandlerMock, forward_to, status_code, state, timeout)
      EM.connect("127.0.0.1", 26784, Client)
    }

    assert       $client_parser
    assert_equal 200,    $client_parser.status_code
    assert_equal "yupd", $client_parser.headers["Server"]
    assert       $service_parser
    assert_equal "/foo", $service_parser.request_url
    assert_equal 3,      Service.attempts
  ensure
    Process.kill("KILL", $pid) if $pid
    state.dispose() if state
  end
end
