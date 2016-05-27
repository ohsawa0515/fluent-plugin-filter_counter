module Fluent
  class CounterFilter < Filter
    Plugin.register_filter('counter', self)

    REGEXP_MAX_NUM = 20

    (1..REGEXP_MAX_NUM).each {|i| config_param :"regexp#{i}",  :string, :default => 1}
    (1..REGEXP_MAX_NUM).each {|i| config_param :"exclude#{i}", :string, :default => 1}
    config_param :count_interval, :time, :default => 60,
                 :desc => 'The interval time to count in seconds.'
    config_param :threshold, :integer, :defalut => 1

    attr_accessor :interval
    attr_accessor :watcher
    attr_accessor :count
    attr_accessor :last_checked
    attr_accessor :last_count

    def configure(conf)
      super

      @interval = @count_interval.to_i
      @count = @last_count = 0

      @regexps = {}
      (1..REGEXP_MAX_NUM).each do |i|
        next unless conf["regexp#{i}"]
        key, regexp = conf["regexp#{i}"].split(/ /, 2)
        raise ConfigError, "regexp#{i} does not contain 2 parameters" unless regexp
        raise ConfigError, "regexp#{i} contains a duplicated key, #{key}" if @regexps[key]
        @regexps[key] = Regexp.compile(regexp)
      end

      @excludes = {}
      (1..REGEXP_MAX_NUM).each do |i|
        next unless conf["exclude#{i}"]
        key, exclude = conf["exclude#{i}"].split(/ /, 2)
        raise ConfigError, "exclude#{i} does not contain 2 parameters" unless exclude
        raise ConfigError, "exclude#{i} contains a duplicated key, #{key}" if @excludes[key]
        @excludes[key] = Regexp.compile(exclude)
      end
    end

    def start
      super
      @watcher = Thread.new(&method(:watch))
    end

    def shutdown
      super
      @watcher.terminate
      @watcher.join
    end

    def watch
      @last_checked ||= Fluent::Engine.now
      while true
        sleep 0.5
        if Fluent::Engine.now - @last_checked >= @interval
          @last_checked = Fluent::Engine.now
          @last_count = @count
          @count = 0
        end
      end
    end

    def filter_stream(tag, es)
      @count += 1
      matched = false
      new_es = MultiEventStream.new

      es.each { |time, record|
        catch(:break_loop) do
          @regexps.each do |key, regexp|
            throw :break_loop unless match(regexp, record[key].to_s)
          end
          @excludes.each do |key, exclude|
            throw :break_loop if match(exclude, record[key].to_s)
          end
          matched = true
        end

        if !matched
          next
        end

        if @last_count < @threshold
          next
        end

        count = @last_count
        placeholder_values = {
          "count"  => count,
        }
        new_record = reform(record, placeholder_values)

        begin
          new_es.add(time, new_record)
          @count = @last_count = 0
          @is_stream = false
        rescue => e
          router.emit_error_event(tag, time, record, e)
        end
      }
      new_es
    end

    def match(regexp, string)
      begin
        return regexp.match(string)
      rescue ArgumentError => e
        raise e unless e.message.index("invalid byte sequence in") == 0
        string = replace_invalid_byte(string)
        retry
      end
      return true
    end

    def reform(record, placeholder_values)
      record.merge!(placeholder_values)
    end

  end
end
