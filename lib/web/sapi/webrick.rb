# Based on: 
# cgihandler.rb -- CGIHandler Class
#       
# Author: IPR -- Internet Programming with Ruby -- writers
# Copyright (c) 2001 TAKAHASHI Masayoshi, GOTOU Yuuzou
# Copyright (c) 2002 Internet Programming with Ruby writers. All rights
# reserved.
#   
# $IPR: cgihandler.rb,v 1.27 2003/03/21 19:56:01 gotoyuzo Exp $

require 'tempfile'
require 'webrick/httpservlet/abstract'

require 'web'

module Web
  
  class CGD
    class Webrick < Web::CGD
      def send_header( header )
        
      end
    end
  end

  class NarfHandler < WEBrick::HTTPServlet::AbstractServlet

    def initialize(server, name)
      super
      @script_filename = name
      @tempdir = server[:TempDir]
    end
    
    def do_GET(req, res)
      cgi_out = Tempfile.new("webrick.cgiout.", @tempdir)
      cgi_err = Tempfile.new("webrick.cgierr.", @tempdir)
      
      old_stderr = $stderr
      
      begin
        $stderr    = cgi_err
        
        meta = req.meta_vars
        meta["SCRIPT_FILENAME"] = @script_filename
        meta["PATH"] = @config[:CGIPathEnv]
        
        cgd = Web::CGD::Webrick.new(:out => cgi_out,
                                    :in  => StringIO.new( req.body || '' ),
                                    :env => meta   )
        Web::load( @script_filename, :cgd => cgd )
        
        res.status = Web::status.to_i
 
        Web::header.each do |key, val|
          unless key =~ /status/i
            res[key] = val.join(", ")
          end
        end
        
        cgi_out.rewind
        res.body = cgi_out.read
        
        cgi_err.rewind
        if errmsg = cgi_err.read
          if errmsg.size > 0
            @logger.error("NarfHandler: #{@script_filename}:\n" + errmsg)
          end
        end 

      rescue Exception => ex
        #Web::report_error( ex )
        raise HTTPStatus::InternalServerError, ex.message

      ensure
        cgi_out.close(true)
        cgi_err.close(true)
        $stderr = old_stderr
      end
    end
    alias do_POST do_GET
  end
  
end
