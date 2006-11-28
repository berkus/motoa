module Web
    # Web::SimpleDispatcher provides a simple framework for organizing
    # Web applications, combining them with forms and handling forms.
    #
    # The following is an example form template
    # '/myappdir/html/templates/my_app.html
    #
    #    <html>
    #      <body>
    #        <narf:form name="my_form" method="post">
    #          <narf:text name="field1">
    #          <narf:textarea name="field2">
    #        </narf:form>
    #      </body>
    #    </html>
    #
    # Patrick notes: simple dispatcher might not be simple.
    # view as promising alpha
    module SimpleDispatcher #:nodoc: all
	def SimpleDispatcher.trace_dispatcher text
	    if $ADD_TEST_OUTPUT
	    	Kernel.puts text
	    end
	end

	class Link
	    attr_reader :page, :query
	    
	    def initialize page, query
		@page = page
		@query = query
	    end
	    
	    def get_link
		"#{SimpleDispatcher.template_from_class(@page)}?#{Link.make_query_string(Web.encode_objects(@query))}"
	    end
	    
	    def encode
		encode64(Marshal.dump(self))
	    end
	    
	    class << self
		def make_query_string query
		    query.collect do |k,v|
			"#{k}=#{Web.escape(v)}"
		    end.join("&")
		end
		
		def Link.unencode string
		    Marshal.load(decode64(string))
		end
	    end    
	end

        module TemplateMixin
	    def redirect_to_template templateClass, params
		Web.reset_headers
		Web.set_redirect File.join(Web.script_name, "#{templateClass.template}?#{Web.make_query_string(Web.encode_objects(params))}")
	    end

            def assign_params
                params = {}
                Web.keys.each do |k|
                if k
   	            params[k] = Web[k]
                end
              end
              
              Scope.new(self).update( params )
            end
        end

        module TemplateClassMixin
          def template
            SimpleDispatcher::template_from_class self
          end

          def redirect_to params
            Web.reset_headers
            Web.set_redirect File.join(Web.script_name, "#{template}?#{Web.make_query_string(Web.encode_objects(params))}")
          end  
          
          def template_filename
            template + ".html"
          end

          def format_description
            "Template: #{template_filename}, formclass #{name}"
          end

          def was_not_a_submit
            Web["__submitted"] == ""
          end
          
          def handle aTemplate
            if was_not_a_submit
 #             trace_dispatcher format_description
            else
#              trace_dispatcher "Submit to: #{name}"
              aTemplate.assign_params
              aTemplate.on_submit({})
            end
            
            Web.print_template template_filename, 
                         aTemplate, Web.encode_objects(Web.query)
          end
        end

	class Template
            include TemplateMixin

            class << self
              include TemplateClassMixin
            end
	end

	class << self
	    def class_from_template template
		template.gsub(/(^|_)([a-z])/) { |m| m.gsub('_','').upcase }		
	    end
	   
	    def template_from_class aClass
		first = true
		aClass.name.gsub(/([A-Z])/) do |m| 
		    value = m.downcase
		    if first
			first = false
			value
		    else
			"_" + value
		    end
		end
	    end
	   
            def template_from_path_info
              if (Web.get_cgi.path_info != "/")
		if (m = /\/?(.+)\/?/.match(Web.get_cgi.path_info))
                  eval(class_from_template(m[1]))
                end
              end
            end

	    def handle_request options
                unless formclass = template_from_path_info
		    options[:default].redirect_to Web.query
		    return
		end

                aTemplate = formclass.new(Web.query)

                formclass.handle aTemplate
	    end
	end
    end
end
