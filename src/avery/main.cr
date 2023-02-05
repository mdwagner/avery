##
# Architecture (WIP)
#
# Pipeline:
#   - pipelines follow the AWK model (BEGIN,PATTERN,END)
#   - pipelines have 3 types of Handlers: Begin, Stream, End
#   - pipelines (Begin) can only run once, unless calling reset
#   - pipelines (Stream to End) can run multiple times
#   - todo: pipelines keep a log/record in debug mode
#   - reset: `context.files.clear` and `context.state.clear`
#
# Begin:
#   - runs once
#   - defines files to process
#   - defines (shell) processes in background
#   - defines state in `context.state[namespace] = Class.new`
#   - defines files in `context.files[file_path] = FileContext.new`
#
# Stream:
#   - runs multiple times
#   - works on each individual file defined by Begin Handlers
#   - can modify files multiple times (across sequential Stream Handlers)
#
# End:
#   - runs after all Stream Handlers (runs once per compile)
#   - gets all finalized files from Stream Handlers
#   - creates,copies,deletes,etc. files for whatever use required
##

##
# Sprockets Input
# :data (context.files[].file_contents) - The string contents of the asset
# :environment (context) - The current Sprockets::Environment instance
# :cache (?) - The Sprockets::Cache instance
# :uri (context.files[].file_uri) - The asset URI
# :source_path (context.files[].file_path) - The full path to original file
# :load_path (X) - The current load path for the file
# :name (context.files[]) - The logical name of the file
# :content_type (context.files[].file_mime_type) - The MIME type of the output asset
# :metadata (context.state) - The Hash of processor metadata
#
# Sprockets Output
# :data (context.files[].file_contents) - Replaces the assets input[:data] for the next processor in the chain
# :required (X) - A Set of String asset URIs that Bundle processor should concatenate together
# :stubbed (X) - A Set of String asset URIs that will be omitted from the :required set
# :links (X) - A Set of String asset URIs that should be compiled along with the assets
# :dependencies (X) - A Set of String cache URIs that should be monitored for caching
# :map (?) - An Array of source maps for the assets
# :charset (context.files[].file_mime_type) - The MIME charset for an asset
##

##
# Context
#   - files : Hash(String, FileContext)
#   - state : Hash(String, State)
#
# files:
#   - key: string path of file
#   - value: file context that tracks file through Stream handlers
#
# state:
#   - key: namespace of custom state
#   - value: custom state to be used throughout all handlers
##

require "uri"
require "digest/md5"
require "file_utils"
require "json"
require "mime"

module Avery
  class FileContext
    getter file_path : String
    property file_contents : String = ""
    property! file_uri : URI?
    property! file_mime_type : String?
    property! file_md5 : String?

    def initialize(@file_path)
    end
  end

  module State
  end

  class Context
    getter files = {} of String => FileContext
    getter state = {} of String => State
    property! current_file : FileContext?
  end

  module Handler
    abstract def call(context : Context)
  end

  class Pipeline
    getter begin_handlers = [] of Handler
    getter stream_handlers = [] of Handler
    getter end_handlers = [] of Handler
    @context = Context.new
    @has_run_begins = false

    def execute
      unless @has_run_begins
        begin_handlers.each do |handler|
          handler.call(@context)
        end
        @has_run_begins = true
      end

      @context.files.each do |file, ctx|
        @context.current_file = ctx
        stream_handlers.each do |handler|
          handler.call(@context)
        end
      end
      @context.current_file = nil

      end_handlers.each do |handler|
        handler.call(@context)
      end
    end

    def reset : Nil
      @context.files.clear
      @context.state.clear
      @has_run_begins = false
    end
  end
end

class CountFilesProcessed
  include Avery::State
  KEY = "count"

  getter count = 0

  def increment
    @count += 1
  end
end

class CustomBeginHandler
  include Avery::Handler

  def call(context)
    Dir.glob("src/**/*.js", "src/**/*.css") do |file|
      context.files[file] = Avery::FileContext.new(file)
    end
    context.state[CountFilesProcessed::KEY] = CountFilesProcessed.new
  end
end

class CustomStreamHandler
  include Avery::Handler

  def call(context)
    if context.current_file?
      content = File.read(current_file.file_path)
      current_file.file_contents = content
      current_file.file_md5 = Digest::MD5.hexdigest(content)
      current_file.file_mime_type = MIME.from_filename(current_file.file_path)

      if state = context.state[CountFilesProcessed::KEY]?
        if state.class == CountFilesProcessed
          klass = state.as(CountFilesProcessed)
          klass.increment
        end
      end
    end
  end
end

class CustomEndHandler
  include Avery::Handler

  def call(context)
    public_dir = Path.new("public")
    assets_dir = public_dir.join("assets")
    manifest_json_path = public_dir.join("manifest.json")
    manifest = {} of String => String

    context.files.values.each do |ctx|
      file = ctx.file_path
      path = Path.new(file)
      content = ctx.file_contents
      md5 = ctx.file_md5
      key_path = strip_components(path, 1)

      case ext = path.extension
      when ".js", ".css"
        basename = File.basename(file, ext)
        new_file = assets_dir.join(key_path.dirname, "#{basename}.#{md5}#{ext}")
        FileUtils.mkdir_p(new_file.dirname)
        FileUtils.cp(file, new_file)
        manifest[key_path.to_s] = "/#{strip_components(new_file, 1)}"
      end
    end

    File.write(manifest_json_path, manifest.to_pretty_json)

    if state = context.state[CountFilesProcessed::KEY]?
      if state.class == CountFilesProcessed
        klass = state.as(CountFilesProcessed)
        puts "Files Processed: #{klass.count}"
      end
    end
  end

  private def strip_components(path : Path, strip)
    Path.new(path.parts[strip..])
  end
end

##
# Example
#
# pipeline = Avery::Pipeline.new
# pipeline.begin_handlers << CustomBeginHandler.new
# pipeline.stream_handlers << CustomStreamHandler.new
# pipeline.end_handlers << CustomEndHandler.new
# pipeline.execute
##
