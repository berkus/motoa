require 'tempfile'

module Web
  # == Purpose
  # This class delegates to the uploaded Tempfile, and adds
  # content type and original filename attributes.
  #
  # If you are testing a multipart/form, use this class
  # to pretend you uploaded a file:
  #
  #     "uploaded_file" => Upload.new(anIO,
  #                                   "image/png",
  #                                   "my_favorite_image.png" )
  #
  # See Web::Testing for more information.
  #
  class Upload
    attr_reader :content_type, :original_filename
    
    def initialize( tempfile, content_type, original_filename )
      if (tempfile.is_a? String)
        contents = File.open( tempfile, "r" ) { |f| f.read }
        tempfile = Tempfile.new("Web")
        tempfile.binmode
        tempfile.write contents
        tempfile.rewind
      end		
      
      @content_type = content_type
      @original_filename = original_filename
      @tempfile = tempfile
    end
    
    # use this method to move an upload somewhere you care about
    def write_to_file( filename )
      File.open( filename, "w" ) { |f|
        f.binmode
        f.write( self.read )
      }
    end
    
    # how do I get the contents of an upload?
    def read
      @tempfile.rewind
      @tempfile.read
    end
    
    # how do I get in IO object from an upload?
    def open
      @tempfile.rewind
      yield @tempfile
    end
  end

end
