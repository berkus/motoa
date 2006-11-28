module Web
  # == Purpose
  #
  # Web::CGI is the core of Narf.  You will find documentation for many
  # useful methods here.  I recommend calling these methods through the
  # Web module, which will manage the current CGI object and delegate
  # to it.
  # 
  class CGI

    # set the singleton cgi object for Web
    def CGI.set_cgi cgi
      Thread.current[:cgi] = cgi
    end
	
    # get the singleton cgi object for Web
    def CGI.get_cgi( options={} )
      unless Thread.current[:cgi]
        CGI.set_cgi( Web::CGI.new(options) )
      end

      Thread.current[:cgi]
    end

    def CGI::create(options = {})
      CGI::new(options)
    end

    include Test::Unit::Assertions

    attr_reader :session, :options

    def document_root
      @cgd.env['document_root']
    end
    
    def script_name
      @cgd.env['script_name']
    end
    
    def path_info
      @cgd.env['path_info']
    end
    
    def cgd
      @cgd
    end

    
    # Construct cgi with the given options.  Defaults are in parenthesis.
    # These options are alpha and due for change as narf supports
    # different backends.
    #
    # [:session]    set the session to the given hash (Web::Session).
    # [:cgd]        pass in a CGD driver
    # [:env]        pass in the ENV variables
    # [:in]         set the input stream to the given IO ($stdin).
    # [:out]        set the output stream to the given IO ($stdout).
    # [:unbuffered] flag whether output should(n't) be buffered. (false)
    # [:path_info]  path_info is the part of the query that is after the script,
    #               i.e. the Narf.html in /wiki.rb/Narf.html (Request.path_info)
    # [:document_root] Document root of website.  (Request.document_root)
    # [:script_name]   Script name, ie /wiki.rb in /wiki.rb/Narf.html (Request.script_name)
    def initialize(options={})
      @options = options
      @cgd = options[:cgd] || CGD.create( options )

      ENV_KEYS.each { |symbol|
        env[symbol.to_s.downcase] = options[symbol] if options[symbol]
      }

      # set output buffer
      @content = StringIO.new
      if (unbuffered?)
        @output = @cgd.output
      else
        @output = StringIO.new
      end
      @cgd.output.binmode if @cgd.output.respond_to? :binmode
      
      @session = if (options.has_key? :session)
                   options[:session]
                 else
                   Session.new( self, options )
                 end
    end

    def trace_output
      templater = Narflates.new(CGI.trace_output_template,{})
      templater.parse(self,{ "parameters" => 
                            multiple_params.collect { |key,value| { "key" => key, "value" => value } },
                            "cookies" =>
                            cookies.collect { |key,value| { "key" => key, "value" => value } },
                            "session" =>
                            session.collect { |key,value| { "key" => key, "value" => value } } })
      flush
    end


    # returns params as a hash of arrays
    def params
      @cgd.multiple_params
    end

   
    # set multiple params, in case you want to change the state of your app
    # without a round trip to the client.
    def params= other
      @cgd.multiple_params = other
    end

    alias :multiple_params :params
    alias :multiple_params= :params=


    MULTIPLE_KEY = /\[\]\z/
    
    # access parameters.  If the key is array-style,
    # aka param[], return the array.  Otherwise,
    # return the joined string.
    def [] (key)
      if (MULTIPLE_KEY =~ key)
        multiple_params[key]
      else
        single_param(key)
      end
    end

    # set param at the given key.  This is useful to change state
    # in your app without asking the browser to redirect
    def []= (key, value)
      unless value.kind_of? Array
        value = [value]
      end
      multiple_params[key] = value
    end

    # If params[key][0] is a Web::Upload, returns that value.
    # Otherwise it returns params[key].join( "," )
    def single_param(key)
      if (multiple_params[key].first.kind_of? Web::Upload)
        multiple_params[key].first
      else
        multiple_params[key].join( "," )
      end
    end
    
    def split_params #:nodoc:
      Web::Testing::MultiHashTree.new(multiple_params).fields
    end
    
    # list the submitted params
    def keys
      multiple_params.keys
    end
    
    # test whether a param was submitted
    def key? (key)
      multiple_params.has_key? key
    end
    
    # array of cookies sent by the client
    def cookies
      @cgd.cookies
    end

    #----------------------------------
    # Response methods
    #----------------------------------
    
    # Append output to client
    [ :<<, :puts, :write, :print ].each{ |symbol|
      define_method(symbol) { |*args|
        send_header if (unbuffered?)
        @content.send( symbol, args )
        @output.send( symbol, args )
      }
    }

    # Reset output buffer.  Fails if headers have been sent.
    def clear()
      if header_sent?
        raise( Exception.new( "Can't call Web::clear()" ) )
      else
        @output = StringIO.new
        @content = StringIO.new
      end
    end

    # This method will replace the contents
    # of the output buffer by reading from
    # the given filename.  If the content-type
    # has not already been set, it will try
    # and guess an appropriate mime-type
    # from the extension of the file.
    #
    # Note: this doesn't flush the output,
    # you can still keep writing after
    # this method.
    def send_file( filename )
      clear()
      write( File.open( filename, 'rb' ) { |f| f.read } )
      if self.content_type == "text/html"
        self.content_type = Web::Mime::get_mimetype(filename)
      end
      Web::close()
    end

    def unbuffered?
      @options[:unbuffered]
    end

    # send header to the client, and flush any buffered output
    def flush
      unless unbuffered?
        send_header
        @cgd.output << @output.string
        @output = StringIO.new
      end
    end

    # returns the body content of the response
    # (sans headers).
    def get_content
      @content.string
    end

    # for testing: raises Test::Unit exception if content
    # is not set to the provided string.
    def assert_content expected, message=""
      assert_equal( expected, get_content, message );
    end
    
    def get_formreader #:nodoc:
      return @form_fields_cache ||= FormReader.new( get_content )
    end
    
    def get_form( name ) #:nodoc:
      get_formreader[name]
    end
    
    def get_form_fields(name) #:nodoc:
      get_formreader.get_fields(name)
    end
    
    def get_form_value formname, name #:nodoc:
      form = get_form_fields(formname)
      if form == nil
        raise Web::Error.new("Form '#{formname}' does not exist") 
      end
      
      value = form[name]
      value
    end
    
    # assert output content contains a form
    # that includes the given hash of values.  See Web::Testing
    def assert_form_includes formname, vars
      assert_includes vars, get_form_fields(formname)
    end

    # flushes the output and, if applicable, saves the session
    def close
      flush
      if $DISPLAY_TRACE
        trace_output
      end
      @session.save if (@session.respond_to? :save)
      @cgd.close
    end
    
    # There's a bit of special casing in here, for the follow reasons:
    # * some headers should only be sent once.  If you add
    #   Content-Encoding, Location, or Status, it will overwrite the old headers
    #   instead of adding a second header
    # * content-type is a strange header.  It is a combination of the content-type
    #   and charset attributes.  setting content-type will cause the content-type
    #   attribute to be set; setting charset will cause the charset attribute to
    #   be set.
    #
    #   I don't know if this is the correct behavior.  Should this method assume that
    #   the content-type set here is the full content type, and try to split the
    #   header into it's two parts?
    #
    # * If the headers have been sent, this will throw a Web::Error
    def add_header(name , value )
      unless header_sent?
        if (/content-encoding/i =~ name  )
          header['Content-Encoding'] = [value]
        elsif( /location/i =~ name )
          header['Location'] = [value]
        elsif( /status/i =~ name )
          if /^\d*$/ =~ value.to_s
            self.status = value
          else
            header['Status'] = [value]
          end
        elsif(/content-type/i =~ name)
          header['Content-Type'] = [value]
        elsif(/charset/i =~ name)
          self.charset = value
        else
          header[name] ||= []
          header[name].push value
        end
      else
        raise Web::Error.new( "Can't add_header after header have been sent to client" )
      end
    end

    # returns an array of header values set with the given name.
    def get_header name
      header.keys.find_all { |key|
        key.downcase == name.downcase
      }.collect{ |key|
        header[key].dup
      }.flatten
    end

    
    # Send header to the client.  No more header values can be sent after this method is called!
    def send_header
      unless header_sent?
        @cgd.send_header( self.header )
        @header_sent = true
      end
    end

    def header_sent?
      @header_sent
    end
    
    def header 
      @header ||= {"Content-Type" => ["text/html"],
                   "Status" => ["200 OK"] }
      @header
    end
    
    # Raises Test::Unit::AssertionFailedError if the header
    # has not been set to the provided value(s)
    def assert_header( name, values, message="" )
      assert_equal( [values].flatten, get_header(name), message )
    end

    # the default status is 200
    def status
      get_header( "Status" ).first =~ /^(\d+)( .*)?$/ 
      $1
    end
    
    def status= new_status
      add_header( "Status", "#{ new_status } #{ Web::HTTP_STATUS[new_status.to_s] }" )
    end

    def location
      get_header( "Location" ).first
    end

    # see set redirect
    def location= location
      add_header( "Location", location )
    end
    
    # Sets the status and the location appropriately.
    def set_redirect( new_location )
      self.status = "302"
      self.location = new_location
    end
    
    def encoding
      get_header( "Content-Encoding" ).first
    end

    def encoding=( new_encoding )
      add_header( "Content-Encoding", new_encoding )
    end

    def split_content_type( target = full_content_type )
      target.split( Regexp.new('; charset=') )
    end

    # The content type header is a combination of the content_type and the charset.
    # This method returns that combination.
    def full_content_type
      get_header( "Content-Type" ).first
    end

    def set_full_content_type( new_content, new_charset )
      add_header( "Content-type", [ new_content, new_charset ].compact.join('; charset=') )
    end

    # the default content-type is "text/html"
    def content_type
      split_content_type[0]
    end

    def content_type= new_content_type
      content1, charset1 = split_content_type
      content2, charset2 = split_content_type( new_content_type )
      
      set_full_content_type( content2 || content1,
                             charset2 || charset1 )
    end
    
    def charset
      split_content_type[1]
    end

    def charset= new_charset
      set_full_content_type( content_type, new_charset )
    end
    
    # Cookies require a name and a value.  You can also use these
    # optional keyword arguments:
    # <b>:path</b> => <i>string<i>:: path (need better description)
    # <b>:domain</b> => <i>string</i>:: domain (need better description)
    # <b>:expires</b> => <i>date</i>:: date this cookie should expire
    # <b>:secure</b> => <i>true || false </i>:: whether this cookie should be
    #                                           tagged as secure.
    def set_cookie( name, value, options={} )
      value = Array(value).collect{ |field|
        Web::escape(field)
      }.join("&")
      
      cookie = "#{ name }=#{ value }"
      
      
      path = if (options[:path])
               options[:path]
             else
               %r|^(.*/)|.match(env["script_name"])
               ($1 or "")
             end
      
      cookie += "; path=#{ path }"
      
      if (options[:domain])
        cookie += "; domain=#{ options[:domain] }"
      end
      
      if (options[:expires])
        cookie += "; expires=#{ Web::rfc1123_date( options[:expires] ) }"
      end
      
      if (options[:secure])
        cookie += "; secure"
      end
      
      add_header( "Set-Cookie", cookie )
    end

    # returns an array of cookie values that have been set.
    # path / expires / etc. info is currently not returned, should
    # be added in?
    def get_cookie key
      get_header("Set-Cookie").collect{ |cookie|
        /\A(#{ key })=([^;]*)/ =~ cookie
        $2
      }.compact
    end

    # returns a hash of all the cookie n/v pairs that have
    # been set on the cgi
    def cookies_sent
      cookies = {}
      get_header("Set-Cookie").each do |cookie|
        /\A(.*?)=([^;]*)/ =~ cookie
        cookies[$1] = $2
      end
      cookies
    end

    # Throws Test::Unit::AssertionFailedException if
    # cookie values are not present.
    def assert_cookie( name, values, message="" )
      assert_equal( [values].flatten, get_cookie(name), message )
    end
    
    # Aside from when :nph is set in the options, scripts running in IIS always
    # use nph mode.  This code will probably be affected as cgi is re-organized
    # to support multiple backends.
    def nph?
      @cgd.nph?
    end
    
    # ENV variables, scoped to the cgi (for in-process servers)
    def env
      @cgd.env
    end

    ENV_KEYS = [ :path_info, :document_root, :script_name ]

    ENV_KEYS.each{ |symbol|
      define_method( symbol ) {
        env[symbol.to_s]
      }
    }

    #------------------------------
    # implementation details, aka
    # refactoring targets below
    #------------------------------

  end

  # == Purpose
  # this is the implementation of the cgi interface.
  # As dbi to dbd, cgi to cgd
  class CGD

    attr_accessor :options, :env, :input, :output, :cookies, :multiple_params
    
    include Parser
    
    def CGD::create(options={})
      case CGI::server_sniff
      when :fcgi
        require 'web/sapi/fastcgi'
        Web::CGD::Fastcgi.new( options )
      when :mod_ruby
        require 'web/sapi/mod_ruby'
        Web::CGD::ModRuby.new( options )
      else
        CGD.new(options)
      end
    end
    
    def initialize(options={})
      @options  = options
      
      @input    = options[:in]  || $stdin
      @output   = options[:out] || $stdout
      @env      = downcase_env( options[:env] || ENV )

      @env['document_root'] = options[:document_root] || Web.get_docroot || @env['document_root']
      @env['script_name' ]  = options[:script_name] || @env['script_name']
      
      parse_request
    end

    def close
      
    end

    # should this be server specific?
    def nph?
      @options[:nph] || /IIS/.match(env["server_software"])
    end
    
    def send_header( header )
      send_nph_header( header ) if (nph?)
    
      header.sort.each { |name, value|
        value.each { |v|
          output << "#{ name }: #{ v }\r\n"
        }
      }
      
      output << "\r\n"
    end
    
    def send_nph_header( header ) #:nodoc:
      output << "#{ env['server_protocol'] || 'HTTP/1.0' }: "
      output << "#{ header['Status'] }\r\n"
      output << "Date: #{ Web::rfc1123_date(Time.now) }\r\n"
      
      header.delete("Status")
      
      unless header.has_key? "Server"
        header["Server"] = [ env["server_software"] || "" ]
      end
    end
    
  end

  class CGI
    TRACE_PATTERN = /^((\w:){0,1}.*?):(\d+)(:?(.*))$/
    def report_error( err )
      # write to error log
      $stderr.binmode
      $stderr.puts err.class.to_s + ": " + err.to_s
      err.backtrace.each do |line|
        $stderr.puts "  " + line.chomp
      end
      # end write to error log
     
      # write to browser
      title = err.class.to_s
      
      msg = "<b style='font-size:20px'>" + err.to_s.gsub(/\n/,"<br>") + "</b><br>"
      msg += Time::now().to_s

      msg += <<-STYLE
<style type="text/css">
.columnHead {
  background-color:CCCDDD;
  text-align:center;
  font-weight:bold;
}
.info {
  text-align:center;
}
.info_row:hover{
  background-color:F8FF80;
}
</style>
STYLE
      msg += "<p><table onMouseover=\"changeto(event, '#F8FF80')\" onMouseout=\"changeback(event, '#eeeeff')\">\n"
      msg += "<tr><td class='columnHead'>File</td><td class='columnHead'>&nbsp;Line&nbsp;</td><td class='columnHead'>Method</td></tr>\n"
           
      err.backtrace.each do |level|
        level =~ TRACE_PATTERN
        level = [ $1, $3, $5 ]
        msg += "<tr class='info_row'>\n"
        level.each{ |column| msg += "<td class='info'>" + (column || '') + "</td>\n" }
        msg += "</tr>\n\n"
      end
      
      msg += "</table>"
      
      Web::print_message( title, msg )
      # end write to browser
    end
    
    # returns one of these values:
    # :cgi, :fastcgi, :mod_ruby, :webrick
    def CGI::server_sniff
      if( Object.const_defined?( "Apache" ) \
          && Apache.const_defined?( "Request" ) \
          && $stdin.kind_of?( Apache::Request ) )
        :mod_ruby
      elsif ( Object.const_defined?( "FCGI" ) \
              && ! FCGI.is_cgi? )
        :fcgi
      else
        :cgi
      end
    end

    def CGI::basic_process( options={}) #:nodoc:
      unless Thread::current[:in_process]
        Thread::current[:in_process] = true
        Web.set_cgi( CGI.new( options ) )
        
        begin
          case Web["narf_resource"]
          when "narf-logo.gif"
            Web::send_lib_file('resources/narf-logo.gif')
          when "narf-styles.css"
            Web::send_lib_file('resources/narf-styles.css')
          when "highlight_table.js"
            Web::send_lib_file('resources/highlight_table.js')
          else
            yield Web.get_cgi
          end
        rescue Exception => error
          if (options[:testing])
            raise error
          else
            Web::report_error( error )
          end
        end

        Web.get_cgi.close
        Thread::current[:in_process] = false
        Web.get_cgi
      else
        yield Web.get_cgi
        Web.get_cgi
      end
    end
    
    
    # try to include fastcgi
    begin
      require 'fcgi'
    rescue LoadError
      
    end
    
    def CGI::process( options={}, &block )
      if CGI::server_sniff == :fcgi
        FCGI::each_request{ |fcgi|
          options[:fcgi] = fcgi
          CGI::basic_process( options, &block )
        }
      else
        CGI::basic_process(options, &block )
      end
    end
    
    end
end
