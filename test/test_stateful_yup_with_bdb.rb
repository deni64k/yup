require 'helper'

require 'tmpdir'
require 'fileutils'
require 'yup/state/bdb'

class TestStatefulYupWithBDB < YupTestCase
  class RequestHandlerMock < Yup::RequestHandler
  end

  def test_request_handler
    Service.attempts = 0

    dbpath           = Dir.mktmpdir("yupd-db")
    uri              = "bdb://#{dbpath}"
    feedback_channel = File.join(Dir.tmpdir, "yupd-#{$$}-feedback")
    forward_to       = "127.0.0.1:26785"
    status_code      = 200
    state            = Yup::State::BDB.new(uri, forward_to, feedback_channel)
    timeout          = 1

    Yup.resend_delay     = 1
    Yup.retry_unless_2xx = true

    $pid = Process.fork do
      Yup::State::BDB::RequestForwarder.new(state, forward_to, timeout).run_loop
    end

    EM.run {
      EM.start_server("127.0.0.1", 26785, Service)
      EM.start_unix_domain_server(feedback_channel, Yup::State::BDB::FeedbackHandler, state)
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
    FileUtils.remove_entry_secure(dbpath) if dbpath
  end
end
