module Web 
    # WritableIO uses << operator to add io style write, print, and puts methods
    module WritableIO # :nodoc:
	# writes object to output stream
	def write object
	    self << object
	end

	# writes objects to the output stream
	def print( *objects )
	    if (objects.empty?)
		self << $_
	    else
		self << objects.collect{ |s| s.to_s }.join("")
	    end
	    if $\ then self << $\ end
        end
	
	# writes multiple lines to the output stream
	def puts( *objects )
	    objects.flatten!
	    self  << objects.collect{ |s|
		s.to_s 
	    }.collect{ |s|
		unless ( /(\r|\n)\z/ =~ s )
		    s + $/
		else
		    s
		end
	    }.join("")
	end
    end
end

begin
    require('stringio') 
rescue LoadError    
  module Web
    class StringIO  # :nodoc:
      def initialize
        @___content___ = ""
      end
      
      def read
        @___content___
      end
      
      def clear
        @___content___ = ""
      end
      
      def string
        @___content___
      end
      
      def puts(*args)
        @___content___ << args.join("\n") << "\n"
      end
      
      def << var
        @___content___ << var.to_s
      end
      
      def write var
        @___content___ << var.to_s
      end
      
      def print var
        @___content___ << var.to_s
      end
    end
  end
  
  unless Kernel.const_defined? "StringIO"
    StringIO = Web::StringIO.clone
  end
end

