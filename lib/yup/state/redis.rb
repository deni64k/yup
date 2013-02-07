begin
  require 'redis'
  require 'redis-namespace'
rescue LoadError
  abort "Install redis-namespace gem to use a persistent queue."
end

module Yup
  module State
    class Redis
      def initialize(uri, forward_to)
        @uri = URI.parse(uri)
        @ns  = @uri.path[1..-1]
        @ns  = "yup-#{VERSION}" if @ns.empty?
        @ns << ":#{forward_to}"

        @logger = Yup.logger.clone
        @logger.progname = "Yup::State::Redis"

        @redis_backend = ::Redis.new(:host => @uri.host, :port => @uri.port)
        @redis         = ::Redis::Namespace.new(@ns, :redis => @redis_backend)
      end

      def push(data)
        @logger.debug { "Push: #{data}" }
        @redis.lpush("requests", data)
      end

      def pushback(data)
        @logger.debug { "Push back: #{data}" }
        @redis.lpush("requests", data)
      end

      def bpop
        _, data = @redis.brpop("requests", :timeout => 0)
        @logger.debug { "Bpoped: #{data.strip}" }
        data
      end

      def dispose
      end

      class RequestForwarder < ::Yup::State::RequestForwarder
        def initialize(*args)
          super
          @logger = Yup.logger.clone
          @logger.progname = "Yup::State::Redis::RequestForwarder"
        end
      end
    end
  end
end
