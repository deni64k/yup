require 'rubygems'
require 'eventmachine'

require 'yup/request_forwarder'
require 'yup/request_handler'

module Yup
  @@resend_delay = 5.0
  def self.resend_delay
    @@resend_delay
  end
  def self.resend_delay=(seconds)
    @@resend_delay = seconds
  end

  def self.run(config)
    host = config[:listen_host] || 'localhost'
    port = config[:listen_port] || 8080
    status_code = config[:status_code] || 200
    forward_to  = config[:forward_to]

    EventMachine::run do
      EventMachine::start_server(host, port, RequestHandler,
                                 forward_to, status_code)
      puts "listening on #{host}:#{port}"
    end
  end
end
