#!/usr/bin/ruby

require 'web'
require 'web/phprb'

docroot = ENV["DOCUMENT_ROOT"]

Web.set_docroot docroot

$: << "#{docroot}/../src"
$: << "#{docroot}/../config"

module Web
  SHEBANG_PATTERN = /^#!.*?[\r\n\f]/
    
  def Web::load( scriptname, options = { } )
    if ARGV.first == '--ruby'
      options[:style] ||= :ruby
      ARGV.shift
    end
    
    if (scriptname == ARGV.first )
      ARGV.shift
    end
    
    if (scriptname =~ /\.rb$/i)
      options[:style] ||= :ruby
    elsif (scriptname =~ /\.narf$/i)
      options[:style] ||= :narf
    elsif (scriptname =~ /\.rhtml$/i)
      options[:style] ||= :narf
    end
    
    options[:style] ||= :narf
    
    case options[:style]
    when :narf
      Web::load_narf( scriptname, options )
    when :ruby
      Web::load_ruby( scriptname, options )
    end
  end
  
  def Web::load_ruby( scriptname, options = {} )
    Web::process(options) do
      raise "Web::load -- no scriptname to run (nil)" unless scriptname
      
      Kernel::load( scriptname )
    end
  end
  
    
  def Web::load_narf( scriptname, options = {} )
    Web::process(options) do
      begin
        raise "Web::load -- no scriptname to run (nil)" unless scriptname

        narf_src = File.open(scriptname,'r'){|f|f.read}
        ruby_src = narf_src.gsub( SHEBANG_PATTERN, '' )
        
        script = PHPRB.new(ruby_src)
        script.filename = scriptname
        Web::puts( script.result )
        
      # print out html on syntax error
      rescue SyntaxError => err
        if (options[:testing])
          raise err
        else
          message = err.message
          # munging message is hard, and I am afraid
          Web::print_message( err.class.to_s, "<table><tr><td><pre>#{message}</pre></td></tr></table>" )
        end
      end
    end
  end
end
