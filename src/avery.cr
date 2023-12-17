require "log"

module Avery
  VERSION = {{ `shards version #{__DIR__}`.chomp.stringify }}
  Log = ::Log.for("avery")

  class FileState
    Log = Avery::Log.for("state")

    getter path : String
    property contents : String = ""
    property! mime_type : String?
    property! md5 : String?

    def initialize(@path)
    end

    def log(message : String)
      Log.info { message }
    end
  end

  class Context
    Log = Avery::Log.for("context")

    property files = {} of String => FileState
    property cache = {} of String => String
    property! current_file : FileState?

    def add_file(path : String)
      @files[path] = FileState.new(path)
    end

    def log(message : String)
      Log.info { message }
    end
  end

  alias Handler = Proc(Context, Nil)

  class Pipeline
    Log = Avery::Log.for("pipeline")

    @initializers = [] of Handler
    @streams = [] of Handler
    @destroyers = [] of Handler
    getter? is_running = false
    property context = Context.new

    def execute
      Log.notice { "New Pipeline started" }
      Log.info { "Pipeline initializers: #{@initializers.size}" }
      Log.info { "Pipeline streams: #{@streams.size}" }
      Log.info { "Pipeline destroyers: #{@destroyers.size}" }

      unless is_running?
        Log.notice { "Pipeline not running yet" }
        Log.info { "Invoking initializers" }
        # call initializers
        @initializers.each do |handler|
          handler.call(@context)
        end
        Log.info { "Completed initializers" }
        @is_running = true
      end
      Log.notice { "Pipeline is running" }

      Log.info { "Invoking streams" }
      # for each file, call streams
      @context.files.each do |file, state|
        @context.current_file = state
        @streams.each do |handler|
          handler.call(@context)
        end
      end
      @context.current_file = nil
      Log.info { "Completed streams" }

      Log.notice { "Pipeline is cleaning up" }

      Log.info { "Invoking destroyers" }
      # call destroyers
      @destroyers.each do |handler|
        handler.call(@context)
      end
      Log.info { "Completed destroyers" }
      Log.notice { "Pipeline is done" }
    end

    def define_initializer(&block : Handler) : Nil
      @initializers << block
    end

    def define_stream(&block : Handler) : Nil
      @streams << block
    end

    def define_destroyer(&block : Handler) : Nil
      @destroyers << block
    end

    def reset : Nil
      @context.files.clear
      @context.state.clear
      @is_running = false
    end
  end
end
