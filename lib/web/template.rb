require 'strscan'

NOT_TOKEN = /(.*?)(?=[<{]\/?[n$])/m
MAXFILESIZE = 1000000

module Web
  class TemplateException < Exception     # :nodoc:

  end
  
  class Node  # :nodoc:
    attr_reader :canonical_name, :value, :parent, :name
    attr_accessor :anAlias, :scope

    def initialize canonical_name, value, parent, name
      @canonical_name = canonical_name
      @value = value
      @parent = parent
      @name = name
    end

    def each 
      @value.each_with_index { |value,i|
	yield Scope.new(value,"#{@canonical_name}[#{i}]",@scope,@anAlias)
      }
    end
  end

  NODE = /^([\w?_]+)/
  SEPARATOR = /^\./
  ARRAY_VAR = /^\[(\d+)\]$/
  ARRAY = /^\[(\d+)\]/
  VAR = /^([\w?_]+)$/

  class Scope  # :nodoc: all
    def concat_name rootname, name
      if rootname != ""
	"#{rootname}.#{name}" 
      else
	"#{name}"
      end
    end

    attr_reader :rootname, :anAlias

    def initialize hash, rootname ="", parent = nil, anAlias = ""
      @hash = hash
      @rootname = rootname
      @parent = parent
      @anAlias = anAlias
    end
    
    class VarNotFoundException < Exception # :nodoc:
    end

    def pull_value( name, collection )
      value = if collection.kind_of? Hash
		raise(VarNotFoundException.new("'#{name}' not found in #{collection.inspect}")) unless collection.has_key? name
		collection[name]
	      elsif collection.kind_of? Array
		raise(VarNotFoundException.new("'#{name}' not found in #{collection.inspect}")) unless collection.has_key? name.to_i
		collection[name.to_i]
	      elsif collection.respond_to? name.intern
		collection.send name.intern
	      else
		raise(VarNotFoundException.new("'#{name}' not found in #{collection.inspect}"))
		#			collection.instance_eval { eval "@" + name }
	      end
      
      #	    raise(VarNotFoundException.new("'#{name}' not found in #{collection.inspect}")) if value == nil

      value
    end
    
    def resolve_recurse scanner, hash, rootname
      scanner.scan(SEPARATOR)
      if scanner.scan(VAR)
	nodename = scanner[1]
	return Node.new(concat_name(rootname,nodename),pull_value( nodename, hash ),hash,nodename)
      elsif scanner.scan(NODE)
	nodename = scanner[1]
	return resolve_recurse(scanner, pull_value( nodename, hash ), concat_name(rootname, nodename))
      elsif scanner.scan(ARRAY_VAR)
	nodename = scanner[1]
	return Node.new(concat_name(rootname,"[" + nodename + "]"),pull_value( nodename, hash ),hash,nodename)
      elsif scanner.scan(ARRAY)
	#TODO check is hash->array
	index = scanner[1]
	return resolve_recurse(scanner, hash[index.to_i], "#{rootname}[#{index}]")
      else
	raise(scanner.rest)
      end
    end

    def resolve varname, anAlias = ""
      # strip alias off front of varname
      varname = varname.sub(/\A#{@anAlias}\./, "")
      raise "Varname is empty" if varname.empty? 
      node = begin
	       scanner = StringScanner.new(varname)
	       resolve_recurse scanner, @hash, @rootname
	     rescue VarNotFoundException => error
	       if @parent
		 @parent.resolve varname
	       else
		 raise error
	       end
	     end
      node.anAlias = anAlias
      node.scope = self
      node
    end

    def update submitted
      submitted.keys.each { |param|
	begin
	  var = resolve param
	  if var.parent.kind_of? Hash
	    var.parent[var.name] = submitted[param]
	  elsif var.parent.kind_of? Array
	    var.parent[var.name.to_i] = submitted[param]
	  else
	    var.parent.send( (var.name + "=").intern, submitted[param] )
	  end
	rescue VarNotFoundException
	end
      }
      @hash
    end
  end

  # == Purpose
  # Templates allow you to seperate the design, which is a constant,
  # from the things that change.  Testing is much easier if you can
  # focus on just the things that change.
  # 
  # <i>Note: Narf intends to support multiple templating libraries.
  # After supporting multiple backends, I will work on the supporting
  # multiple templating libraries.  I will probably start with rdoc
  # and amrita.</i>
  #
  # Back to business!  Here's an example Narflate:
  #
  #     <html>
  #       <body>
  #         {$myvar}
  #         <narf:foreach from=alist item=i>
  #           {$i.x}, {$i.x}<br>
  #         </narf:foreach>
  #       </body>
  #     </html>
  #
  # You use the Web::print_template( template, value_hash ) to print
  # the template merged with values:
  #
  #     --- script.rb:
  #     Web::process do
  #       Web.print_template "mytemplate.html",
  #       		   "field1" => "val1",
  #       		   "field2" => "val2",
  #     	  	   "field3" => "val3",
  #     		   "field4" => "3",
  #     		   "values" => [{ "name" => "one", "value" => "1"},
  #     		                { "name" => "two", "value" => "2"},
  #     				{ "name' => "three", "value" => "3"}]
  #     end
  #
  #     --- mytemplate.html:
  #     <narf:input type="text" name="field1">
  #     <narf:input type="hidden" name="field2">
  #     <narf:textarea name="field3">
  #     <narf:select name="field4" values="values">
  #     
  # This will produce the output:
  # 
  #     <input type="text" name="field1" value="val1">
  #     <input type="hidden" name="field2" value="val2">
  #     <textarea name="field3">
  #     val3
  #     </textarea>
  #     <select name="field3">
  #     	<option value="1">one</option>
  #     	<option value="2">two</option>
  #     	<option value="3" selected>three</option>
  #     </select>
  # 
  class Narflates  
    attr_reader :templates #:nodoc

    # This is the default template_include_path
    def Narflates.template_include_path #:nodoc:
      [Dir.pwd,
       File.join(Web.document_root.to_s,
                 Web.script_path.to_s,
                 "templates" ).gsub( /\/\//, "/" ),
      ]
    end
    
    def Narflates.template_file( template ) #:nodoc:
      template_file = template
      Web.template_include_path.reverse.each{ |dir|
	full_template_path = File.join( dir, template )
	if (File.exists? full_template_path)
	  template_file = full_template_path
	end
      }
      template_file
    end
    
    def initialize template, query = {} 	# :nodoc:
      @templates = [template]
      @template = if (File.exists? Narflates.template_file(template))
                    File.open(Narflates.template_file(template), "r") do |file|
                      file.read || "" # this is because of a fixed bug in ruby.
                    end                # eventually the || "" should disappear
                  else
                    template
                  end
      @parser = StrScanParser.new(StringScanner.new( @template ))
      @query = query
    end
    
    def parse io, vars 	# :nodoc:
      vars = if vars.kind_of? Scope
	       vars
	     else
	       Scope.new(vars)
	     end
      
      parse_recurse.each do |item|
	item.print(vars,io)
      end
     
    end

    class Foreach 	  # :nodoc:
      attr_reader :array, :itemname, :contents
      def initialize (array,itemname,contents)
	@array = array
	@itemname = itemname
	@contents = contents
      end

      def print (globals,io) 
	globals.resolve(array,@itemname).each { |item|
	  contents.each { |i|
	    i.print(item,io)
	  }
	}
      end
    end

    class Form  	# :nodoc:
      attr_reader :formname, :method
      def initialize (formname,method,contents,query)
	@formname = formname
	@method = method
	@contents = contents
	@query = query
      end

      def print (globals,io) 
	io << "<form name=\"#{@formname}\" method=\"#{@method}\">"
	io << "<input type=\"hidden\" name=\"__submitted\" value=\"#{@formname}\">"
	@query.each do | k,v|
	  io << "<input type=\"hidden\" name=\"__q.#{k}\" value=\"" + v.gsub(/"/,"&quot;") +"\">"
	end

	@contents.each do |i|
	  i.print(globals,io)
	end
	io << "</form>"
      end
    end

    class If 	# :nodoc:
      attr_reader :condvar, :contents
      def initialize (condvar,contents)
	@condvar = condvar
	@contents = contents
      end

      def print (globals,io) 
	var = globals.resolve(@condvar)
	if var.value && var.value != []
	  contents.each { |i|
	    i.print(globals,io)
	  }
	end
      end
    end

    class Unless	# :nodoc:
      attr_reader :condvar, :contents
      def initialize (condvar,contents)
	@condvar = condvar
	@contents = contents
      end

      def print (globals,io) 
	var = globals.resolve(@condvar)
	unless var.value || var.value == []
	  contents.each { |i|
	    i.print(globals,io)
	  }
	end
      end
    end

    class Var 	# :nodoc:
      attr_reader :varname
      def initialize (varname)
	@varname = varname
      end

      def print (globals,io) 
	io << globals.resolve(@varname).value
      end
    end

    class Link  	# :nodoc:
      def initialize (link,contents)
	@link = link
	@contents = contents
      end

      def print (globals,io) 
	io << "<a href=\"#{globals.resolve(@link).value.get_link}\">"
	@contents.each { |i| 
	  i.print(globals,io)
	} 
	io << "</a>"
      end
    end 

    class Include  	# :nodoc:
      def initialize (filename, vars, template_list)
	@vars = vars
	@filename = filename
	@template_list = template_list
      end

      def print (globals,io) 
	# resolve filename if it is var
	filename = if @filename =~ /^\$(.*)/
		     globals.resolve( $1 ).value
		   else
		     @filename
		   end

	# load file
	
	unless File.exists? Web::Narflates.template_file(filename)
	  raise(TemplateException.new("Could not locate template file: " + filename))
	end

	templater = Narflates.new(filename,@query)
	
	if @vars == nil
	  templater.parse(io, globals )
	else
	  templater.parse(io, Scope.new(globals.resolve(@vars).value))
	end
        
	@template_list.concat( templater.templates )
      end
    end

    class Data 	# :nodoc:
      attr_reader :data
      def initialize (data)
	@data = data
      end

      def print (globals,io) 
	io << @data if @data != nil
      end
    end

    class Text  	# :nodoc:
      attr_reader :name
      def initialize (name)
	@name = name
      end        

      def print (globals,io) 
	var = globals.resolve(@name)
	io << "<input type=\"text\" name=\"#{var.canonical_name}\" value=\"#{var.value}\">"
      end
    end

    class Hidden  	# :nodoc:
      attr_reader :name
      def initialize (name)
	@name = name
      end        

      def print (globals,io) 
	var = globals.resolve(@name)
	io << "<input type=\"hidden\" name=\"#{var.canonical_name}\" value=\"#{var.value}\">"
      end
    end

    class Password  	# :nodoc:
      attr_reader :name
      def initialize (name)
	@name = name
      end        

      def print (globals,io) 
	var = globals.resolve(@name)
	io << "<input type=\"password\" name=\"#{var.canonical_name}\" value=\"#{var.value}\">"
      end
    end

    class CheckBox  	# :nodoc:
      attr_reader :name
      def initialize (name)
	@name = name
      end        

      def print (globals,io) 
	var = globals.resolve(@name)
	io << "<input type=\"checkbox\" name=\"#{var.canonical_name}\""
	if var.value == true
	  io << " checked>"
	end
	io << "><input type=\"hidden\" name=\"__#{var.canonical_name}\" value=\"e\">"
      end
    end

    class TextArea 	# :nodoc:
      attr_reader :name
      def initialize (name,rows,cols,virtual,style,id)
	@name = name
	@rows = rows
	@cols = cols
	@virtual = virtual
	@style = style
        @id = id
      end        

      def print (globals,io) 
	value = globals.resolve(@name).value
	io << "<textarea id=\"#{@id}\" name=\"#{@name}\" rows=\"#{@rows}\" cols=\"#{@cols}\" virtual=\"#{@virtual}\" style=\"#{@style}\">#{value}</textarea>"
      end
    end

    class Select  	# :nodoc:
      attr_reader :name, :values
      def initialize (name,values)
	@name = name
	@values = values
      end        
      
      def print (globals,io) 
	value = globals.resolve(@name).value
	values = globals.resolve(@values).value
	io << "<select name=\"#{@name}\">"
	
	values = values.collect { |i|
	  unless i.kind_of? Hash
	    { "name" => i, "value" => i }
	  else
	    { "name" => i["name"], "value" => i["value"] }
	  end
	}

	values.each { |item|
	  item = item
	  selected = if item["value"].to_s == value.to_s
		       " selected"
		     else
		       ""
		     end
	  io << "<option value=\"#{item['value']}\"#{selected}>#{item['name']}</option>"
	}
	io << "</select>"
      end
    end


    def match_identifiers tree=[]  	# :nodoc:
      @parser.match_identifier do |identifier|
	tree.push Var.new(identifier)
      end
    end


    def match_tags tree=[] 	# :nodoc:
      @parser.match_tag() do |tag|
	case tag.name
	when "input"
	  case tag.attributes["type"]
	  when "text"
	    tree.push Text.new(tag.attributes["name"])			
	  when "hidden"
	    tree.push Hidden.new(tag.attributes["name"])
	  when "password"
	    tree.push Password.new(tag.attributes["name"])
	  when "checkbox"
	    tree.push CheckBox.new(tag.attributes["name"])
	  end
	when "textarea"
	  tree.push TextArea.new(tag.attributes["name"],tag.attributes["rows"],tag.attributes["cols"],tag.attributes["virtual"],tag.attributes["style"],tag.attributes["id"])
	when "foreach"
	  parse_recurse("foreach") { |contents| 
	    tree.push Foreach.new(tag.attributes["from"],tag.attributes["item"],contents)
	  }
	when "form"
	  parse_recurse("form") { |contents| 
	    tree.push Form.new(tag.attributes["name"],tag.attributes["method"],contents,@query)
	  }
	when "link"
	  parse_recurse("link") { |contents| 
	    tree.push Link.new(tag.attributes["value"],contents)
	  }
	when "select"
	  tree.push Select.new(tag.attributes["name"], tag.attributes["values"])
	when "if"
	  parse_recurse("if") do |contents|
	    tree.push If.new(tag.attributes["condition"],contents)		
	  end
	when "unless"
	  parse_recurse("unless")do |contents|
	    tree.push Unless.new(tag.attributes["condition"],contents)
	  end
	when "include"
	  tree.push Include.new(tag.attributes["file"],tag.attributes["vars"],@templates)
	else
	  #TODO: raise unknown token exception
	end
      end
    end
    
    def parse_recurse closeTag = nil, tree = [], &block  	# :nodoc:
      catch(:done) do
	while @parser.rest? do
	  @parser.match( NOT_TOKEN ) do |m|
	    tree.push Data.new(m[1])
	  end 
	  
	  @parser.match_close_tag do |tag|
	    if closeTag # TODO: make sure the correct close tag is given
	      yield(tree) if block
	      throw :done
	    end
	  end ||
	    match_identifiers(tree) || 
	    match_tags(tree) ||
	    (tree.push(Data.new(@parser.rest)) &&
	     throw(:done))
	end     
      end
      tree
    end
  end


  module TemplatePrinter #:nodoc:
    attr_reader :template_name, :template_vars
    # writes template to self.  Added by require 'narf/template'
    # template can be a filename or a template string
    def print_template (template, template_object ={}, query={})
      flush
      @template_vars = template_object
      templater = Narflates.new(template,query)
      templater.parse(self ,template_object)
      @templates = templater.templates
    end

    # this must be an instance variable so that one can append
    # to the include path without
    # carrying over to the next test
    def template_include_path
      @template_include_path ||= Web::Narflates.template_include_path
      #Web::Narflates.template_include_path
    end
    
    # Check that a particluar template was used 
    def assert_template_used expected, message =""
      _wrap_assertion {
        raise TemplateException.new("No template used") if @templates == nil
        unless @templates.include? expected
          msg = "expected template:<#{expected}> but not one of:<#{@templates.inspect}>"
          flunk(msg)
        end
      }
    end
    
    # Check that a particluar template was not used 
    def assert_template_not_used expected, message =""
      _wrap_assertion {
        raise TemplateException.new("No template used") if @templates == nil
        if @templates.include? expected
          msg = "template:<#{expected}> not supposed to be used in:<#{@templates.inspect}>"
          flunk(msg)
        end
      }
    end
    
    # Check that these values were included in the output
    def assert_vars_includes expected
      assert_includes expected, @template_vars
    end

    def assert_vars_equals
      raise Exception.new("Not yet implemented")
    end
  end
  
  class CGI
    include TemplatePrinter
  end
end
