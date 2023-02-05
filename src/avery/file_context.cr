class Avery::FileContext
  getter file_path : String
  property file_contents : String = ""
  property! file_mime_type : String?
  property! file_md5 : String?

  def initialize(@file_path)
  end
end
