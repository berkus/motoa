require 'tempfile'

module Web
  # == Purpose
  #
  # this hash is has case insensitive keys.  Might be somewhat
  # incomplete
  class CaseInsensitiveHash < Hash #:nodoc:
    def [](key)
      super( key.to_s.downcase )
    end
    
    def []= (key, value)
      super( key.to_s.downcase, value )
    end

    def has_key? (key)
      super( key.to_s.downcase )
    end
  end

  # == Purpose
  #
  # This module contains methods to parse web requests.
  # Parser counts on the attributes of a cgd: options, input, env
  module Parser

    # This method counts on the attributes of a cgd: options, input, env
    # It will set @cookies and @multiple_params
    def parse_request
      @cookies  ||= normalize(options[:cookies] ||
                              parse_cookie( env['http_cookie'] ||
                                            env['cookie'] ) )

      @multiple_params ||= normalize( options[:params] ||
                  parse_params )

    end

    # returns a hash with downcased keys of the env_in variable
    def downcase_env( env_in )
      env = CaseInsensitiveHash.new
      env_in.each{ |k, v|
        env[k.downcase] = v
      }
      env
    end

    # normalizes a params hash
    def Parser.normalize( params )
      params.each { |key, value|
        unless value.kind_of? Array
          params[key] = [value]
        end
      }
      params.default = []
      params
    end

    def normalize(params)
      Parser.normalize(params)
    end

    # Parse a raw cookie string
    def Parser.parse_cookie(raw_cookie)
      cookies = Hash.new([])
      return cookies unless raw_cookie
      
      raw_cookie.split(/; /).each do |pairs|
        name, values = pairs.split('=',2)
        name = Web::unescape(name)
        values ||= ""
        values = values.split('&').collect{|v| Web::unescape(v) }
        if cookies.has_key?(name)
          cookies[name].push(*values)
        else
          cookies[name] = values
        end
      end
      
      cookies
    end
    
    def parse_cookie(raw_cookie)
      Parser.parse_cookie(raw_cookie)
    end

    # parse and return multiple_params
    def parse_params
      if (multipart?)
        parse_multipart
      else
        parse_query_string( query_string )
      end
    end
    
    def query_string #:nodoc:
      case env["request_method"]
      when "GET", "HEAD"
        if (defined? MOD_RUBY) # <= this check is untested.
          #    search the test files for
          #    test_parse_get_with_mod_ruby
          #    for an explanation
          mod_ruby_query_string
        else
          env["query_string"]
        end
      when "POST"
        input.binmode
        input.read(Integer(env['content_length']))
      end
    end
    
    # this method solely exists b/c of difficulties setting MOD_RUBY dynamically.
    # so this method exists so I can test the effect separately
    # from the (currently untestable) cause
    def Parser.mod_ruby_query_string     #:nodoc:
      Apache::request.args
    end
    
    def mod_ruby_query_string #:nodoc:
      Parser.mod_ruby_query_string
    end
    
    # Parse a query_string into parameters
    def Parser.parse_query_string(query)
      query ||= ""
      params = Hash.new([])
      
      query.split(/[&;]/n).each do |pairs|
        key, value = pairs.split('=',2).collect{|v| Web::unescape(v) }
        if params.has_key?(key)
          params[key].push(value)
        else
          params[key] = [value]
        end
      end
      
      params
    end

    def parse_query_string(query)
      Parser.parse_query_string(query)
    end
    
    # note this returns the un-arrayified version of the array
    def parse_query_string_typed(query) #:nodoc: :notest:
      params = parse_query_string query
      params2 = {}
      params.collect do |k,v|
        if ! (k =~ /type/)
          if (atype = params["#{k}#type"][0]) 
            params2[k] = Module.const_get(atype.intern).unencode(v[0])
          else
            params2[k] = v[0]
          end
        end
      end
      params2
    end
    
    def multipart?
      ("POST" == env['request_method']) &&
            (/multipart\/form-data/.match(env['content_type']))
    end
    
    # parse multipart/form-data
    def parse_multipart
      %r|\Amultipart/form-data.*boundary=\"?([^\";,]+)\"?|n.match(env['content_type'])
      boundary = $1.dup
      
      read_multipart(boundary, Integer(env['content_length']))
    end
    
    EOL="\r\n"
    
    def read_multipart(boundary, content_length)  #:nodoc:
      params = Hash.new([])
      boundary = "--" + boundary
      buf = ""
      bufsize = 10 * 1024
      
      # start multipart/form-data
      input.binmode
      boundary_size = boundary.size + EOL.size
      content_length -= boundary_size
      status = input.read(boundary_size)
      if nil == status
        raise EOFError, "no content body"
      end
      
      # ok... so what the hell does this do?
      # I promise never to denigrate the accomplishments
      # of my predecessors again :-)
      #    ~ pat
      until -1 == content_length
        head = nil
        body = Tempfile.new("Web")
        body.binmode
        
        # until we have:
        #   * a header
        #   * and a buffer that has a boundary
        # so far, make sense to me.
        until head and /#{boundary}(?:#{EOL}|--)/n.match(buf)
          # if we have a header....
          if head
            # !??!??!?!?!
            trim_size = (EOL + boundary + EOL).size
            if trim_size < buf.size
              body.print buf[0 ... (buf.size - trim_size)]
              buf[0 ... (buf.size - trim_size)] = ""
            end
          
          # If we have a double space (the smell of a header...)
          elsif /#{EOL}#{EOL}/n.match(buf)
            # extract the header, and erase it from the buffer
            buf = buf.sub(/\A((?:.|\n)*?#{EOL})#{EOL}/n) do
              head = $1.dup
              ""
            end
            next
          end
          
          # read a chunk from the input
          c = if bufsize < content_length
                input.read(bufsize) or ''
              else
                input.read(content_length) or ''
              end
          # add it to the input, reduce our countdown
          buf.concat c
          content_length -= c.size
        end
        
       /Content-Disposition:.* filename="?([^\";]*)"?/ni.match(head)
        filename = ($1 or "").dup
        if /Mac/ni.match(env['http_user_agent']) and
            /Mozilla/ni.match(env['http_user_agent']) and
            (not /MSIE/ni.match(env['http_user_agent']))
          filename = Web::unescape(filename)
        end
        
        /Content-Type: (.*)/ni.match(head)
        content_type = ($1 or "").strip
        
        # is this the part that is eating too much?
        #buf = buf.sub(/\A(.*?)(?:#{EOL})?#{boundary}(#{EOL}|--)/mn) do
        buf = buf.sub(/\A((?:.|\n)*?)(?:[\r\n]{1,2})?#{boundary}([\r\n]{1,2}|--)/n) do
          body.print $1
          if "--" == $2
            content_length = -1
          end
          ""
        end
        
        body.rewind

     
        if (content_type.empty?)
          upload = body.read
        else
          upload = Web::Upload.new( body, content_type, filename )
        end

        /Content-Disposition:.* name="?([^\";]*)"?/ni.match(head)
        name = $1.dup


        body.rewind

        if params.has_key?(name)
          params[name].push(upload)
        else
          params[name] = [upload]
        end
        
      end
      
      params
    end # read_multipart
    
  end
end
