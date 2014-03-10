module Fluent
  require 'fluent/plugin/in_tail'
  require 'fluent/mixin/config_placeholders'

  class TailExAsisInput < TailInput
    Plugin.register_input('tail_ex_asis', self)

    config_param :expand_date, :bool, :default => true
    config_param :read_all, :bool, :default => true
    config_param :refresh_interval, :integer, :default => 3600

    include Fluent::Mixin::ConfigPlaceholders

    def initialize
      super
      @ready = false
      @parser = nil
    end

    def configure_parser(conf)
      @parser = AsisParser.new
      @parser.configure(conf)
    end

    def configure(conf)
      super
      if @tag.index('*')
        @tag_prefix, @tag_suffix = @tag.split('*')
        @tag_suffix ||= ''
      else
        @tag_prefix = nil
        @tag_suffix = nil
      end
      @watchers = {}
      @refresh_trigger = TailWatcher::TimerWatcher.new(@refresh_interval, true, &method(:refresh_watchers))
    end

    def expand_paths
      date = Time.now
      paths = []
      for path in @paths
        if @expand_date
          path = date.strftime(path)
        end
        paths += Dir.glob(path)
      end
      paths
    end

    def refresh_watchers
      paths = expand_paths
      missing = @watchers.keys - paths
      added = paths - @watchers.keys

      stop_watch(missing) unless missing.empty?
      start_watch(added) unless added.empty?
    end

    def start_watch(paths)
      paths.each do |path|
        if @pf
          pe = @pf[path]
          if @read_all && pe.read_inode == 0
            inode = File::Stat.new(path).ino
            pe.update(inode, 0)
          end
        else
          pe = nil
        end

        watcher = TailExAsisWatcher.new(path, @rotate_wait, pe, &method(:receive_lines))
        watcher.attach(@loop)
        @watchers[path] = watcher
      end
    end

    def stop_watch(paths, immediate=false)
      paths.each do |path|
        watcher = @watchers.delete(path)
        if watcher
          watcher.close(immediate ? nil : @loop)
        end
      end
    end

    def receive_lines(lines, tag)
      if @tag_prefix || @tag_suffix
        @tag = @tag_prefix + tag + @tag_suffix
      end
      super(lines)
    end

    def start
      paths, @paths = @paths, []
      super
      @thread.join
      @paths = paths
      refresh_watchers
      @refresh_trigger.attach(@loop)
      @ready = true
      @thread = Thread.new(&method(:run))
    end

    def shutdown
      @refresh_trigger.detach
      stop_watch(@watchers.keys, true)
      @loop.stop
      @thread.join
      @pf_file.close if @pf_file
    end

    def run
      # don't run unless ready to avoid coolio error
      if @ready
        super
      end
    end

    class TailExAsisWatcher < TailWatcher
      def initialize(path, rotate_wait, pe, &receive_lines)
        @parent_receive_lines = receive_lines
        super(path, rotate_wait, pe, &method(:_receive_lines))
        @close_trigger = TimerWatcher.new(rotate_wait * 2, false, &method(:_close))
      end

      def _receive_lines(lines)
        tag = @path.tr('/', '.').gsub(/\.+/, '.').gsub(/^\./, '')
        @parent_receive_lines.call(lines, tag)
      end

      def close(loop=nil)
        detach                  # detach first to avoid timer conflict
        if loop
          @close_trigger.attach(loop)
        else
          _close
        end
      end

      def _close
        @close_trigger.detach if @close_trigger.attached?
        self.class.superclass.instance_method(:close).bind(self).call

        @io_handler.on_notify
        @io_handler.close
        $log.info "stop following of #{@path}"
      end
    end
    class AsisParser
      include Configurable
      config_param :asis_key, :string, :default => 'message'
      def parse(text)
        record = {}
        record[@asis_key] = text
        return Engine.now, record
      end
    end
  end
end
