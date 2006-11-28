module Web
  # == Purpose
  # This class returns mime types.  It parses an apache-style mime.types file
  # located in site_lib/web/resources/mime.types for it's database.
  # 
  # This class can be independantly of the rest of NARF:
  #
  #     require 'web/mime.rb'
  #     Web::Mime::get_mime_type( 'filename.txt' )
  #
  class Mime
    DEFAULT_MIMETYPE  = "text/html"
    @@readers = []
    def Mime.readers
      @@readers
    end
    
    class ApacheUnixReader #:nodoc:
      MIME_FILENAME = "resources/mime.types"
      COMMENTED_PATTERN = /(^\s*#)|(^\s*$)/
      VALUE_PATTERN     = /\.*(\S+)\s*=\s*(\S+)/
      
      def self.mime_file
        Web::lib_filename( MIME_FILENAME )
      end
      
      def self.applies?
        File.exists? mime_file
      end
      
      def mime_types
        mime_array = File.open( self.class.mime_file, "r" ) { |f|
          f.read.to_a
        }
        mime_array.uniq!
        mime_array.delete_if { |line|
          line =~ COMMENTED_PATTERN
        }
        mime_hash = {}
        mime_hash.default = DEFAULT_MIMETYPE
        mime_array.each { |line|
          pieces = line.split( /\s+/ )
          mime_type = pieces.shift
          pieces.each { |extension|
            mime_hash[extension] = mime_type
          }
        }
        mime_hash
      end
      
      Mime.readers.push self
    end
    
    @@mime_types = nil

    class << self
      def clear
        @@mime_types = nil
      end

      def mime_types
        unless(@@mime_types)
          readers.each{ |klass|
            if klass.applies?
              @@mime_types = klass.new.mime_types
              break
            end
          }
        end
        @@mime_types
      end

      def get_mime_type( filename )
        mime_types[filename.split(".").last].to_s
      end
      alias :get_mimetype :get_mime_type
    end
  end
  
  class << self
    def get_mime_type(filename)
      Mime.get_mime_type(filename)
    end
    alias :get_mimetype :get_mime_type
  end

end 
