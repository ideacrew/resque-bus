module QueueBus
  module Adapters
    class Resque < QueueBus::Adapters::Base
      def enabled!
        # know we are using it
        require 'resque'
        require 'resque/scheduler'
        require 'resque-retry'

        QueueBus::Worker.extend(::Resque::Plugins::ExponentialBackoff)
        QueueBus::Worker.extend(::QueueBus::Adapters::Resque::RetryHandlers)
      end

      def redis(&block)
        block.call(::Resque.redis)
      end

      def enqueue(queue_name, klass, json)
        ::Resque.enqueue_to(queue_name, klass, json)
      end

      def enqueue_at(epoch_seconds, queue_name, klass, json)
        ::Resque.enqueue_at_with_queue(queue_name, epoch_seconds, klass, json)
      end

      def setup_heartbeat!(queue_name)
        # turn on the heartbeat
        # should be down after loading scheduler yml if you do that
        # otherwise, anytime
        name     = 'resquebus_heartbeat'
        schedule = { 'class' => '::QueueBus::Worker',
                     'args'=>[::QueueBus::Util.encode({'bus_class_proxy' => '::QueueBus::Heartbeat'})],
                     'cron'  => '* * * * *',   # every minute
                     'queue' => queue_name,
                     'description' => 'I publish a heartbeat_minutes event every minute'
                   }
        if ::Resque::Scheduler.dynamic
          ::Resque.set_schedule(name, schedule)
        end
        ::Resque.schedule[name] = schedule
      end

      private

      module RetryHandlers
        # @failure_hooks_already_ran on https://github.com/defunkt/resque/tree/1-x-stable
        # to prevent running twice
        def queue
          @my_queue
        end

        def on_failure_aaa(exception, *args)
          # note: sorted alphabetically
          # queue needs to be set for rety to work (know what queue in Requeue.class_to_queue)
          hash = ::QueueBus::Util.decode(args[0])
          @my_queue = hash["bus_rider_queue"]
        end

        def on_failure_zzz(exception, *args)
          # note: sorted alphabetically
          @my_queue = nil
        end
      end
    end
  end
end
