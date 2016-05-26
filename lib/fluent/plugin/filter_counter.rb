module Fluent
  class CounterFilter < Filter
    Plugin.register_filter('counter', self)

    def configure(conf)
      super
    end

    def start
      super
    end

    def shutdown
      super
    end

    def filter_stream(tag, es)
      new_es = MultiEventStream.new
      es.each { |time, record|
        begin
          filtered_record = filter(tag, time, record)
          new_es.add(time, filtered_record) if filtered_record
        rescue => e
          router.emit_error_event(tag, time, record, e)
        end
      }
      new_es
    end
  end
end
