require 'rubygems'
require 'eventmachine'
require 'logger'
require 'yajl'
require 'tmpdir'

require 'yup/request_forwarder'
require 'yup/request_handler'

module Yup
  @@resend_delay = 5.0
  def self.resend_delay; @@resend_delay end
  def self.resend_delay=(seconds); @@resend_delay = seconds end

  @@watermark = 100
  def self.watermark; @@watermark end
  def self.watermark=(seconds); @@watermark = seconds end

  @@logger = Logger.new(STDOUT)
  def self.logger; @@logger end
  def self.logger=(logger); @@logger = logger end

  def self.run(config)
    host = config[:listen_host] || 'localhost'
    port = config[:listen_port] || 8080
    status_code = config[:status_code] || 200
    forward_to  = config[:forward_to]
    timeout     = config[:timeout] || 10

    EventMachine.run do
      EventMachine.start_server(host, port, RequestHandler, forward_to, status_code, nil, timeout)
      logger.info { "listening on #{host}:#{port}" }
    end
  end

  def self.run_with_state(config)
    require 'yup/state'

    host        = config[:listen_host] || 'localhost'
    port        = config[:listen_port] || 8080
    status_code = config[:status_code] || 200
    forward_to  = config[:forward_to]
    dbpath      = config[:persistent]
    timeout     = config[:timeout]
    feedback_channel = File.join(Dir.tmpdir, "yupd-#{$$}-feedback")
    state            = Yup::State.new(dbpath, forward_to, feedback_channel)

    pid = Process.fork do
      State::RequestForwarder.new(state, forward_to, timeout).run_loop
    end

    if pid
      db_closer = proc do
        Yup.logger.info { "Terminating consumer #{$$}" }
        Process.kill("KILL", pid)
        state.close
        exit 0
      end
      Signal.trap("TERM", &db_closer)
      Signal.trap("INT", &db_closer)
    end

    EventMachine.run do
      EventMachine.start_server(host, port, RequestHandler, forward_to, status_code, state, timeout)
      logger.info { "Listening on #{host}:#{port}" }

      EventMachine.start_unix_domain_server(feedback_channel, State::FeedbackHandler, state)
      logger.info { "Feedback through #{feedback_channel}" }
    end
  end
end
