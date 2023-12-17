require "digest/md5"
require "file_utils"
require "json"
require "mime"
require "../src/avery"

class Count
  include JSON::Serializable
  property count : Int32

  def initialize(@count)
  end

  def increment
    @count += 1
  end
end

class CustomDestroyer
  def call(context)
    public_dir = Path.new("public")
    assets_dir = public_dir.join("assets")
    manifest_json_path = public_dir.join("manifest.json")
    manifest = {} of String => String

    context.files.values.each do |state|
      file = state.path
      path = Path.new(file)
      content = state.contents
      md5 = state.md5
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

    if count_json = context.cache["count"]?
      c = Count.from_json(count_json)
      context.log("Files Processed: #{c.count}")
    end
  end

  private def strip_components(path : Path, strip)
    Path.new(path.parts[strip..])
  end
end

pipeline = Avery::Pipeline.new

pipeline.define_initializer do |ctx|
  Dir.glob("src/**/*.js", "src/**/*.css") do |file|
    ctx.add_file(file)
  end
  ctx.cache["count"] = Count.new(0).to_json
end

pipeline.define_stream do |ctx|
  if current_file = ctx.current_file?
    content = File.read(current_file.path)
    current_file.contents = content
    current_file.md5 = Digest::MD5.hexdigest(content)
    current_file.mime_type = MIME.from_filename(current_file.path)

    if count_json = ctx.cache["count"]?
      count = Count.from_json(count_json)
      count.increment
      ctx.cache["count"] = count.to_json
    end
  end
end

pipeline.define_destroyer do |ctx|
  CustomDestroyer.new.call(ctx)
end

pipeline.execute
