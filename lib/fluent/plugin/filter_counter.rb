module Fluent
  class CounterFilter < Output
    Plugin.register_output('counter', self)

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
    attr_accessor :last_tag
    attr_accessor :last_record

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
      @last_checked ||= Engine.now
      while true
        sleep 0.5
        if Engine.now - @last_checked >= @interval
          @last_checked = Engine.now
          @last_count = @count
          flush_emit
        end
      end
    end

    def flush_emit
      output = nil
      if @last_count >= @threshold
        placeholder_values = {
          "count"  => @last_count,
        }
        output = reform(@last_record, placeholder_values)
      end
      router.emit(@last_tag, @last_checked, output)
      @count = @last_count = 0
    end

    def emit(tag, es, chain)
      matched = false
      es.each { |time, record|

        # grep filtering
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

        @count += 1
        @last_tag = tag
        @last_record = record
      }
      chain.next
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
