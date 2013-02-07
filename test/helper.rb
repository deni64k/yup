ENV['RACK_ENV'] = 'test'

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'minitest/unit'

require 'simplecov'
require 'simplecov-rcov'

class SimpleCov::Formatter::MergedFormatter
  def format(result)
    SimpleCov::Formatter::HTMLFormatter.new.format(result)
    SimpleCov::Formatter::RcovFormatter.new.format(result)
  end
end

SimpleCov.formatter = SimpleCov::Formatter::MergedFormatter
SimpleCov.start

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'yup'

class YupTestCase < MiniTest::Unit::TestCase
  def after_setup
    Service.attempts = 0
    super
  end

  class Service < EM::Connection
    @@attempts = 0
    def self.attempts;     @@attempts end
    def self.attempts=(n); @@attempts = n end

    def post_init
      @parser = Http::Parser.new(self)
    end

    def receive_data(data)
      @parser << data
    end

    def on_message_complete
      $service_parser = @parser

      case @@attempts
      when 0
      when 1
        send_data "HTTP/1.1 400 Bad Request\r\nServer: test\r\n\r\n"
        close_connection_after_writing
      when 2
        send_data "HTTP/1.1 200 OK\r\nServer: test\r\n\r\n"
        close_connection_after_writing
      end

      @@attempts += 1
    end

    def unbind
      if @@attempts > 2
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
end

MiniTest::Unit.autorun
