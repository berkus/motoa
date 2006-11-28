# see cgi.rb and Web::process

require 'web/cgi'

module Web
  class CGD
    class Fastcgi < CGD
      def Fastcgi::new( options = {} )
        fcgi = options[:fcgi]
        
        options[:out]  = fcgi.out
        options[:in]   = fcgi.in
        options[:env]  = fcgi.env
        
        super(options) 
      end
      
      def close
        options[:fcgi].finish if options[:fcgi]
        options[:fcgi] = nil
      end
    end
  end
  
end

