module Web
  @@docroot = nil

  # When testing, this is a useful method to tell
  # NARF where to find your scripts
  def Web.set_docroot docroot
    @@docroot = docroot
  end

  def Web.get_docroot
    @@docroot
  end    

  # == Purpose
  # The testing module facilitates the testing of Web applications
  # without the overhead of a web server to run.
  #
  # Given these files:
  #
  #    script.rb
  #    test.rb
  #
  # where script.rb is:
  #
  #    #!/usr/bin/ruby
  #    require 'web'
  #
  #    Web::process { 
  #      Web.write "param is #{Web["param"]}"
  #    }
  #
  # and test.rb is:
  #    
  #    require 'web'
  #    require 'test/unit'
  #
  #    class MyAppTest < Test::Unit::TestCase
  #        include Web::Testing
  #
  #        def test_prints_content
  #            do_request "script.rb", "param" => "THIS!"
  #            assert_content "param is THIS!"
  #        end
  #    end
  #
  # Do this to run tests:
  #
  #     ruby test.rb
  #
  # If you have a more complicated app, where the tests live in
  # a different place than your scripts, you can use:
  #
  #    Web::set_docroot( path )
  #
  # To tell narf where to find your cgi scripts.
  #
  #
  # === Testing with Templates
  # 
  # Using Narflates you can test functionality without having to
  # do lengthly string comparisons.  For example, create the following
  # file in 'mytemplate.html'
  #
  #     <html>
  #       <body>
  #         {$myvar}
  #       </body>
  #     </html>
  # 
  # Create a 'script.rb' as follows:
  #
  #     #!/usr/bin/narf
  #     require 'web'
  #
  #     Web::process{
  #       Web.print_template "mytemplate.html", { "myvar" => "Hello World" }
  #     }
  #
  # Now, we can check that the right values got displayed without
  # needing to check that the template is correct as a side effect.
  # Save this into 'test.rb' and run it:
  #
  #     require 'web'
  #
  #     class MyAppTest < Test::Unit::TestCase
  #         include Web::Testing          # adds the modules
  #
  #         def test_prints_content
  #             do_request "script.rb"
  #             assert_vars_includes "myvar" => "Hello World"
  # 	      end
  #     end
  #
  # === Testing Forms
  #
  # The following example demonstrates testing a simple HTML form.
  # Creating mytemplate.html as:
  #
  #
  #     <html>
  #       <body>
  #         <form name="myform">
  #           <input type="text" name="foo">
  #           <input type="submit" name="submit" value="Submit">
  #       </body>
  #     </html>
  #
  # To print this form and handle a submit save this as 'script.rb':
  #
  #     #!/usr/bin/narf
  #     
  #     require 'web'
  #     
  #     Web::process {
  #       if Web["submit"]   # check to see whether a form was
  #           Web.puts "Form Submitted with value '#{Web["foo"]}'"  
  #       else
  #           Web.print_template "mytemplate.html"
  #       end
  #     }
  #
  # Use this 'test.rb' to test it:
  #
  #     class MyAppTest < Test::Unit::TestCase
  #         include Web::Testing          # adds the modules
  #
  #         def test_prints_content
  # 	          do_request "script.rb"
  #             do_submit "myform", "foo" => "bar"
  #             assert_content "Form Submitted with value '#{Web["foo"]}'"
  # 	      end
  #     end
  #
  #
  # === Test <input type="text|password|hidden"> and <textarea>
  #
  # html:
  #
  #     <form name='aForm'>
  #     <input name="bare">
  #     <input name="named"   type="text"     value="foo">
  #     <input name="pass"    type="password" value="secret">
  #     <input name="obscure" type="hidden"   value="discrete">
  #     <textarea name="big_text">
  #     big paragraph here
  #     </textarea>
  #     </form>
  #
  # assert:
  #
  #     assert_form_includes( 'aForm', "bare"     => "",
  #                                    "named"    => "foo",
  #                                    "pass"     => "secret",
  #                                    "obscure"  => "discrete",
  #                                    "big_text" => "big paragraph here" )
  #
  # submit:
  #
  #     do_submit( 'aForm', "bare"     => "empty",
  #                         "named"    => "bare",
  #                         "pass"     => "shhhhh",
  #                         "obscure"  => "secretive",
  #                         "big_text" => "windbag" )
  #
  # === Test <input type="file">
  #
  # html:
  #
  #     <form name='aForm' enctype='multipart/form-data'>
  #     <input name="upload" type="file">
  #     </form>
  #
  # assert:
  #
  #     assert_form_includes( 'aForm', "upload" => "" )
  #
  # submit:
  #
  #     do_submit( 'aForm', "upload" => Web::Upload.new(
  #                                       File.new( "testfile" ),
  #                                       "content-type",
  #                                       "original-filename" ) )
  #
  # === Test <select> and <input type="radio">
  #
  # 
  #
  # === Test <select multiple> and <input type="checkbox">
  #
  #
  # === Bugs: Unsupported behaviour
  #
  #  The following situations will have unknown results:
  #
  #  * Combining different types of elements into one field;
  #    i.e. <input name="field" type="text"> and <select name="field">
  #  * Comparing <input name="page.name"> and <input name="page.content">
  #    with assert_vars_include("page" => { "name" => ..., "content" => ... } )
  #
  module Testing
    class FormNotFoundException < Exception #:nodoc:
    end

    class FieldNotFoundException < Exception #:nodoc:
    end

    class MustSetDocrootForAbsolutePathException < Exception #:nodoc:
    end

    # When testing, this is a useful method to tell
    # NARF where to find your scripts
    def set_docroot( path )
      Web::set_docroot( path )
    end

    def select( *args )
      hash = {}
      
      if (args.length == 1 and args[0].kind_of? Hash)
        hash = args[0]
      else
        args.each { |e|
          hash[e] = true
        }
      end
      
      hash
    end
    
    @@test_session = nil

    # Reset the session used by the test framework. Call prior to all tests
    # that rely on the session being clean
    def reset_session
      @@test_session = nil
    end
    
    # Run a request, parameters are the name value pairs that would be
    # passed in the query string. The webpath is a document root relative 
    # path to a ruby script.
    def do_request(webpath, parameters={}) 
      options = {}
      @@test_session ||= {}
      options[:session] = @@test_session
      options[:params] = parameters
      options[:document_root] = Web.get_docroot
      options[:out] = StringIO.new
      script_path, script_name, path_info = get_script_part(webpath)
      
      options[:path_info] = path_info
      options[:script_name] = script_name
      load_request( options, script_path, webpath )
    end
    
    def load_request( options, script_path, webpath ) #:nodoc:
      options[:webpath] = webpath

      # out with the old....
      #Web::get_cgi.close
      Web::set_cgi nil
      error = nil
      Web::load( script_path, options )
      
      if Web.status == "302"
	      Web.location =~ /(.*)\?(.*)/
        target = $1
        params = Parser.parse_query_string($2)
        
        unless (target =~ /^\//)
          webpath =~ /(.*)#{File.basename(script_path)}/
          target = $1 + target
	      end
        do_request( target, params )
      end
    end
    
    # Submit the form 'formname' with the formfields described in newvalues
    def do_submit( formname, newvalues={} )
      form = Web.get_form(formname)
      
      if form == nil
        #if Web.get_form_fields[formname] == nil
	raise FormNotFoundException.new("Form '#{formname}' does not exist") 
      end
      
      #MultiHashTree::flatten(newvalues).keys.each do |key|
	#unless( Web.get_form_fields[formname].valid_key?(key) )
	 # raise FieldNotFoundException.new( "#{ key } is not present in form" )
	#end
      #end

      webpath = nil
      
      #Web.get_html_tree.get_elements("form").each { |form|
      #  if (form.attribute("name") == formname)
      #    webpath = form.attribute("action")
      #  end
      #}
      webpath = form.action

      unless (webpath)
        webpath = Web.options[:webpath]
      end

      script_path, script_name, path_info = get_script_part(webpath)

      oldRequest = Web.get_cgi

      options = {}
      @@test_session ||= {}
      options[:session] = @@test_session
      options[:out] = StringIO.new
      ### patrick
      options[:params] = form.merge_fields( newvalues )
      #options[:params] = Web.get_form_fields[formname].params(MultiHashTree::flatten(newvalues))
      options[:document_root] = oldRequest.document_root

      options[:path_info] = path_info     #oldRequest.path_info
      options[:script_name] = script_name #oldRequest.script_name

      load_request( options, script_path, webpath )
    end

    # Assert that a give template was displayed
    def assert_template_used filename, msg=""
      Web.assert_template_used filename, msg
    end

    # Assert that a give template was not displayed
    def assert_template_not_used filename, msg=""
      Web.assert_template_not_used filename, msg
    end

    # Assert that the values passed in to expected were set on the template
    def assert_vars_includes expected
      Web.assert_vars_includes expected
    end
    
    # Assert that the form displayed contains particular values
    def assert_form_includes formname, expected
      Web.assert_form_includes formname, expected
    end
    
    # Assert that the entire content displayed is equal to expected
    def assert_content expected, msg=""
      Web.assert_content expected, msg
    end
    
    # Assert that the header key has the value 'value'
    def assert_header key, value, msg=""
      Web.assert_header key, value, msg
    end

    # Assert that the cookie key, has the cookie value
    def assert_cookie key, value, msg=""
      Web.assert_cookie key, value, msg
    end
    
    # Assert that a form field has exactly the given options
    # can't assert order, though
    def assert_options( formname, expected={})
      options = Web.get_formreader.get_options(formname)
      expected.each{ |k,v|
        assert_equal( v.sort, options[k].sort )
      }
    end

    def remove_trailing_slashes(filename)  #:nodoc:
      /(.*?)\/?$/.match(filename)[1]
    end

    def get_script_part(webpath)  #:nodoc:
      # two cases:
      #   absolute webpath (requires Web.get_docroot to be correct)
      #   relative webpath (doesn't require Web.get_docroot to be correct)
      if ( webpath =~ /^\// )
        prefix = Web.get_docroot
        raise MustSetDocrootForAbsolutePathException unless prefix
        path = "/"
      else
        prefix = ""
        path = ""
      end

      new_script_path = ""
      webpath.split("/").each do |file|
	file =~ /^([a-zA-Z]{1,1}:)$/

        if (path.empty?)
          newpath = file
        else
          newpath = File.join( path , file ).gsub("//","/") 
        end

        new_script_path = ""
        if (prefix.empty?)
          new_script_path = newpath
        else
          new_script_path = File.join( prefix, newpath ).gsub("//","/") 
        end
        
        if (File.file?(new_script_path))
	  return new_script_path, "/" + File.basename( new_script_path ), webpath[newpath.length...webpath.length]
	end 
	
	path = newpath
      end

      if (!File.exists?(new_script_path) && prefix.empty?)
        return get_script_part( "/" + webpath )
      end

      return new_script_path, "/" + File.basename( new_script_path ), ""
    end

    class SelectHash < Hash #:nodoc:
      def == other
        if (other.kind_of? Hash)
          super(other)
        elsif (other.class == TrueClass)
          result = true
          self.each{ |k, v|
            result = false unless v
          }
          result
        elsif (other.class == FalseClass)
          result = true
          self.each{ |k,v|
            result = false if v
          }
          result
        else
          ### this is wrong
          other.to_s == self.default.join(",")
        end
      end

      def field_value
        values = [ ]
        self.each{ |k,v|
          values.push k if v
        }
        values.join(",")
      end

    end

    # could I get an explanation of this?
    # just for me? please?
    # not to long... probably not longer than this comment here.
    class MultiHashTree # :nodoc:
      attr_reader :fields, :unmodified_fields
      
      def initialize fields = {}
        @fields = {}
        @unmodified_fields = {}
        fields.each do |k,value_array|
          value_array.each{ |v|
            push_field k, v
          }
        end
      end
      
      def valid_key? (aKey)
        unmodified_fields.has_key?(aKey) || fields.has_key?(aKey)
      end
      
      def push_impl hash, name, value
        if name =~ Web::CGI::MULTIPLE_KEY && !value.kind_of?(Web::Testing::SelectHash)
          hash[name] ||= []
          hash[name].push  value
        elsif m = /^(\w+(\[\])?)\.(.+)/.match(name)
          hash[m[1]] ||= {}
          push_impl(hash[m[1]], m[3], value)
        elsif m = /^(\w+)\[(\d+)\].(.+)/.match(name)
          hash[m[1]] ||= []
          hash[m[1]][m[2].to_i] ||= {}
          push_impl hash[m[1]][m[2].to_i], m[3], value
        else
          hash[name] ||= []
          hash[name].push(value)
        end
      end

      def push_field name, value
        @unmodified_fields[name] ||= []
        @unmodified_fields[name].push value
        push_impl @fields, name, value
      end
      
      def params values
        retval = @unmodified_fields.clone
        values.each do |key,value|
          if value.kind_of? SelectHash
            selected_options = []
            value.each{ |k,v|
              selected_options.push k if v
            }
            
            if m = Web::CGI::MULTIPLE_KEY.match(key)
              retval[key] ||= []
              retval[key] = (retval[key] + selected_options).uniq
            else
              retval[key] = selected_options.join(",")
            end
            
          else
            if m = Web::CGI::MULTIPLE_KEY.match(key)
              retval[key] ||= []
              retval[key] << value
            else
              retval[key] = value
            end
          end
        end
        retval
      end
      
      def MultiHashTree.flatten node, newhash = {} , nameroot = "" # :nodoc:
        if node.kind_of? Hash
          node.each do |k,v|
            if nameroot == ""
              varname = k
            else
              varname = "#{nameroot}.#{k}" 
            end
            flatten( v, newhash, varname )
          end
        elsif node.kind_of? Array
          unless node.find { |i| !i.kind_of? String }
            newhash[nameroot] = node
          else
            node.each_with_index do |v,i|
              flatten( v, newhash, "#{nameroot}[#{i}]" )
            end
          end
        else
          newhash[ nameroot ]=node
        end
        newhash
      end
      
    end

  end
end
