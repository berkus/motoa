# see cgi.rb and Web::process

require 'web/cgi'

module Web
  class CGD
    class ModRuby < CGD
      def initialize( options = {} )
        options[:env] = {}
        ENV.each{|k,v|
          options[:env][k] = v
        }
        Apache::request.headers_in.each{ |k,v|
          options[:env][k] = v
        }
        super(options)
      end

      def send_header header
        Apache::request.status_line  = header['Status'].first.split.shift
        Apache::request.content_type = header['Content-Type'].first
        Apache::request.content_encoding = (header['Content-Encoding'] || [ ]).first
        
        header.delete( "Status" )
        header.delete( "Content-Type" )
        header.delete( "Content-Encoding" )
        
        if (header["Set-Cookie"])
          header["Set-Cookie"].each{ |cookie|
            Apache::request.headers_out.add( "Set-Cookie", cookie )
          }
          header.delete( "Set-Cookie" )
        end
        
        header.each{ |k,v|
          Apache::request.headers_out[k] = v.last
        }
        
        Apache::request.send_http_header
        
      end

    end
  end
end

