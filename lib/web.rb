require 'test/unit/assertions'

require 'web/strscanparser'
require 'web/action'
require 'web/upload'
require 'web/parser'
require 'web/session'
require 'web/stringio'
require 'web/template'
require 'web/assertinclude'
require 'web/forms'
require 'web/tagparser'
require 'web/testing'
require 'web/formreader.rb'
require 'web/simpledispatcher'
require 'web/traceoutput'
require 'web/mime'
require 'web/info'
require 'web/cgi'
require 'web/runner'

require 'web/htmltools/tree'

# Write output to client.  Replaces Kernel.puts;
# use that or $stderr.puts if you want the standard puts.
#    commented out -- include Web instead ~ pat
#def puts( *args )
#    Web.puts args
#end

# == Purpose
# Web provides an infrastructure for building and testing
# web applications.
#
# == Usage
# Use the Web module to interact with the client.  The module
# delegates to a Web::CGI object, which does the actual work.
#
#     #!/usr/bin/ruby
#     require 'web'
#     Web::process do
#       Web["field"]                      # access parameters
#       Web.cookies["muppet"]             # access cookies
#       Web.session["key"] ||= "value"    # get and set session values
#       Web.set_cookie( "muppet", "cookie monster" ) # set cookies
#       Web.puts "something"              # print 'something' out
#     end
#
# If the request contained multipart/form-data, uploaded files are returned as
# Web::Upload objects.  Other parameters are treated as strings.
#
# == Output
#
# You write output as if it were an IO:
#     Web << "<h1>Hello World!</h1>"
#     Web.print "<p>We have lots of tricks for you.<br>"
#     Web.write "From kungfu to jiujitsu<br>"
#     Web.puts  "anything and everything works</p>."
# or even:
#     puts "hello world"
#
# Narf buffers output by default.  Buffered output allows you to set headers
# (cookies, redirects, status, etc.) at any point before the cgi is flushed.
# You can force this by calling:
#     Web.flush
#
# Once the headers are sent to the client, you cannot set any more headers.
#
# == Error Handling
#
# For cgi-scripts under Apache, one can use the 'bin/narf'
# script instead of using the ruby executable.  This little c program
# doesn't do much fancy, but it can trap syntax errors and send them
# back to the browser.  <i>I would especially appreciate security-related
# feedback; narf.c is contributed and I am not a c programmer.</i>
#
# == Sessions:
#
# Sessions provide a way of storing data between Web
# requests. Anything that can be marshalled can be stored in the
# session. 
#
# === Getting and Setting values in a session
#
#      Web.session["key"] = "value"
#      Web.session["key"]             # => "value"
#
# === Deleting session values
#
#      Web.session["key"] = "value"
#      Web.session["key"].delete      # => "value"
#      Web.session["key"]             # => "nil"
#
# === Iterating through session keys
#
#      Web.session.each do |key, val|
#          Web.puts "#{key} => #{val}<br>"
#      end
#
# === Resetting the Session
#
# Reseting the session to an empty hash is simple:
#     Web.session.reset
#
# === Testing
#
# Narf takes testing very seriously.  I consider supporting
# testing to be part of the contract when writing a IO library.
# See Web::Testing for more details.
#
module Web
    class << self
      # Web delegates to the current
      # cgi object.  This is the recommended
      # way to use narf:
      #
      #    Web["param"]
      #    Web << "hello world"
      #    Web.set_redirect( "http://www.narf-lib.org" )
      #    ...
      # 
      # The documentation for these methods is on the Web::CGI object.
      def method_missing(method, *args, &block)
        CGI.get_cgi.send(method,*args, &block)
      end

      def set_cgi( cgi )
        CGI.set_cgi( cgi )
      end

      def get_cgi
        CGI.get_cgi
      end

      def process(options={}, &block)
        CGI.process(options, &block)
      end

    end
    
    # this function should be useful for web apps that
    # want to store resources with the source files
    # in the ruby lib directories. For example:
    #     Web::lib_filename('resources/logo.gif' )
    # Uses Kernel::caller to determine base directory,
    # use optional dirname parameter to change base directory
    def Web::lib_filename( resource, dirname="missing" )
      if dirname == "missing"
        dirname = caller[1]
        dirname =~ Web::CGI::TRACE_PATTERN
        dirname = File.dirname($1)
      end
      File.join( dirname, resource )
    end
    
    # Get the contents of a lib file, aka
    #    template = Web::lib_file_contents('resources/template.html' )
    # Uses Kernel::caller to determine base directory,
    # use optional dirname parameter to change base directory
    def Web::lib_file_contents( filename, dirname="missing" )
      File.open( lib_filename( filename, dirname ), 'r' ) { |f|
        f.read
      }
    end

    # To send a resource gif to the client:
    #     Web::send_lib_file( 'resources/logo.gif' )
    # Uses Kernel::caller to determine base directory,
    # use optional dirname parameter to change base directory
    def Web::send_lib_file( filename, dirname = "missing" )
      Web::get_cgi::send_file( Web::lib_filename( filename, dirname ) )
    end
    
    # URL-encode a string.
    #   url_encoded_string = Web::escape("'Stop!' said Fred")
    #      # => "%27Stop%21%27+said+Fred"
    # (from cgi.rb)
    def Web::escape(string)
      return nil unless string
      string.gsub(/([^ a-zA-Z0-9_.-]+)/n) do
        '%' + $1.unpack('H2' * $1.size).join('%').upcase
      end.tr(' ', '+')
    end
    
    
    # URL-decode a string.
    #   string = Web::unescape("%27Stop%21%27+said+Fred")
    #      # => "'Stop!' said Fred"
    # (from cgi.rb)
    def Web::unescape(string)
      return nil unless string
      string.tr('+', ' ').gsub(/((?:%[0-9a-fA-F]{2})+)/n) do
        [$1.delete('%')].pack('H*')
      end
    end
    

    # Escape special characters in HTML, namely &\"<>
    #   Web::escape_html('Usage: foo "bar" <baz>')
    #      # => "Usage: foo &quot;bar&quot; &lt;baz&gt;"
    # (from cgi.rb)
    def Web::escape_html(string)
      return nil unless string
      string.gsub(/&/n, '&amp;').gsub(/\"/n, '&quot;').gsub(/>/n, '&gt;').gsub(/</n, '&lt;')
    end

    # include these methods with Web
    
    # Append output to client with line endings
    def puts(*args)
      Web::get_cgi.puts(*args)
    end
    def print(*args)
      Web::get_cgi.print(*args)
    end
    def write(*args)
      Web::get_cgi.write(*args)
    end
    def escape_html(string)
      Web::escape_html(string)
    end
    def unescape_html(string)
      Web::unescape_html(string)
    end
    def escape_element(string, *elements)
      Web::escape_element(string, *elements)
    end
    def unescape_element(string, *elements)
      Web::unescape_element(string, *elements)
    end
    alias escapeHTML escape_html
    alias html_encode escape_html
    alias unescapeHTML unescape_html
    alias escapeElement escape_element
    alias unescapeElement unescape_element

    def rfc1123_date(time)
      Web::rfc1123_date(time)
    end

    # Unescape a string that has been HTML-escaped
    #   Web::unescape_html("Usage: foo &quot;bar&quot; &lt;baz&gt;")
    #      # => "Usage: foo \"bar\" <baz>"
    # (from cgi.rb)
    def Web::unescape_html(string)
      return nil unless string
      string.gsub(/&(.*?);/n) do
        match = $1.dup
        case match
        when /\Aamp\z/ni           then '&'
        when /\Aquot\z/ni          then '"'
        when /\Agt\z/ni            then '>'
        when /\Alt\z/ni            then '<'
        when /\A#0*(\d+)\z/n       then
          if Integer($1) < 256
            Integer($1).chr
          else
            if Integer($1) < 65536 and ($KCODE[0] == ?u or $KCODE[0] == ?U)
              [Integer($1)].pack("U")
            else
              "&##{$1};"
            end
          end
        when /\A#x([0-9a-f]+)\z/ni then
          if $1.hex < 256
            $1.hex.chr
          else
            if $1.hex < 65536 and ($KCODE[0] == ?u or $KCODE[0] == ?U)
              [$1.hex].pack("U")
            else
              "&#x#{$1};"
            end
          end
        else
          "&#{match};"
        end
      end
    end
    

    # Escape only the tags of certain HTML elements in +string+.
    #
    # Takes an element or elements or array of elements.  Each element
    # is specified by the name of the element, without angle brackets.
    # This matches both the start and the end tag of that element.
    # The attribute list of the open tag will also be escaped (for
    # instance, the double-quotes surrounding attribute values).
    #
    #   print Web::escape_element('<BR><A HREF="url"></A>', "A", "IMG")
    #     # "<BR>&lt;A HREF=&quot;url&quot;&gt;&lt;/A&gt"
    #
    #   print Web::escape_element('<BR><A HREF="url"></A>', ["A", "IMG"])
    #     # "<BR>&lt;A HREF=&quot;url&quot;&gt;&lt;/A&gt"
    #
    # (from cgi.rb)
    def Web::escape_element(string, *elements)
      return nil unless string
      elements = elements[0] if elements[0].kind_of?(Array)
      unless elements.empty?
        string.gsub(/<\/?(?:#{elements.join("|")})(?!\w)(?:.|\n)*?>/ni) do
          Web::escape_html($&)
        end
      else
        string
      end
    end

    
    # Undo escaping such as that done by Web::escape_element()
    #
    #   print Web::unescape_element(
    #           Web::escapeHTML('<BR><A HREF="url"></A>'), "A", "IMG")
    #     # "&lt;BR&gt;<A HREF="url"></A>"
    # 
    #   print Web::unescape_element(
    #           Web::escapeHTML('<BR><A HREF="url"></A>'), ["A", "IMG"])
    #     # "&lt;BR&gt;<A HREF="url"></A>"
    # (from cgi.rb)
    def Web::unescape_element(string, *elements)
      return nil unless string
      elements = elements[0] if elements[0].kind_of?(Array)
      unless elements.empty?
        string.gsub(/&lt;\/?(?:#{elements.join("|")})(?!\w)(?:.|\n)*?&gt;/ni) do
          Web::unescape_html($&)
        end
      else
        string
      end
    end
    
    class << self
      alias escapeHTML escape_html
      alias html_encode escape_html
      alias unescapeHTML unescape_html
      alias escapeElement escape_element
      alias unescapeElement unescape_element
    end

    RFC822_DAYS = %w[ Sun Mon Tue Wed Thu Fri Sat ]
    RFC822_MONTHS = %w[ Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec ]
    # Make RFC1123 date string
    #     Web::rfc1123_date(Time.now) # => Sat, 01 Jan 2000 00:00:00 GMT
    def Web::rfc1123_date(time)
      t = time.clone.gmtime
      return format("%s, %.2d %s %.4d %.2d:%.2d:%.2d GMT",
                    RFC822_DAYS[t.wday], t.day, RFC822_MONTHS[t.month-1], t.year,
                    t.hour, t.min, t.sec)
    end
    
    HTTP_STATUS = {"200" => "OK",
                   "206" => "Partial Content",
                   "300" => "Multiple Choices",
                   "301" => "Moved Permanently",
                   "302" => "Found",
                   "304" => "Not Modified",
                   "400" => "Bad Request",
                   "401" => "Authorization Required",
                   "403" => "Forbidden",
                   "404" => "Not Found",
                   "405" => "Method Not Allowed",
                   "406" => "Not Acceptable",
                   "411" => "Length Required",
                   "412" => "Precondition Failed",
                   "500" => "Internal Server Error",
                   "501" => "Method Not Implemented",
                   "502" => "Bad Gateway",
                   "506" => "Variant Also Negotiates"
    }


    TRACE_STYLESHEET=<<-EOF
<style type="text/css">
span.tracecontent { background-color:white; color:black;font: 10pt verdana, arial; }
span.tracecontent table { font: 10pt verdana, arial; cellspacing:0; cellpadding:0; margin-bottom:25}
span.tracecontent tr.subhead { background-color:cccccc;}
span.tracecontent th { padding:0,3,0,3 }
span.tracecontent th.alt { background-color:black; color:white; padding:3,3,2,3; }
span.tracecontent td { padding:0,3,0,3 }
span.tracecontent tr.alt { background-color:eeeeee }
span.tracecontent h1 { font: 24pt verdana, arial; margin:0,0,0,0}
span.tracecontent h2 { font: 18pt verdana, arial; margin:0,0,0,0}
span.tracecontent h3 { font: 12pt verdana, arial; margin:0,0,0,0}
span.tracecontent th a { color:darkblue; font: 8pt verdana, arial; }
span.tracecontent a { color:darkblue;text-decoration:none }
span.tracecontent a:hover { color:darkblue;text-decoration:underline; }
span.tracecontent div.outer { width:90%; margin:15,15,15,15}
span.tracecontent table.viewmenu td { background-color:006699; color:white; padding:0,5,0,5; }
span.tracecontent table.viewmenu td.end { padding:0,0,0,0; }
span.tracecontent table.viewmenu a {color:white; font: 8pt verdana, arial; }
span.tracecontent table.viewmenu a:hover {color:white; font: 8pt verdana, arial; }
span.tracecontent a.tinylink {color:darkblue; font: 8pt verdana, arial;text-decoration:underline;}
span.tracecontent a.link {color:darkblue; text-decoration:underline;}
span.tracecontent div.buffer {padding-top:7; padding-bottom:17;}
span.tracecontent .small { font: 8pt verdana, arial }
span.tracecontent table td { padding-right:20 }
span.tracecontent table td.nopad { padding-right:5 }
</style>
EOF


    # wrapper for web errors
    class Error < Exception # :nodoc:
	
    end

end

module HTMLTree # :nodoc: all
    module TreeElement
	def get_elements aname, elements=[]
	    children.each { |element|
		if element.tag == aname
		    elements.push element
		else
		    element.get_elements aname, elements
		end
	    }
	    elements
	end
    end
end

