require "digest/md5"
require "file_utils"
require "json"
require "mime"
require "../src/avery"

##
# Example
#
# pipeline = Avery::Pipeline.new
# pipeline.begin_handlers << CustomBeginHandler.new
# pipeline.stream_handlers << CustomStreamHandler.new
# pipeline.end_handlers << CustomEndHandler.new
# pipeline.execute
##

class CountFilesProcessed
  include Avery::Context::State
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

