class Array # :nodoc:
  def has_key?(index)
    index >= 0 && index < length
  end
  
  def __index(key)
    self[key]
  end
  
  def compare_includes? haystack, prefix=[]
	message = ""
    each_with_index{ |v, k|
      fullname = prefix.clone
      if fullname.length > 0
        fullname[fullname.length-1] = "#{fullname.last}[#{k}]"
      else
        fullname[0] = "<Array>[#{k}]"
      end
      fullname_str = fullname.join(".")
      message += do_thing(haystack, k, v, fullname, fullname_str)
    }
    message
  end
end


class Object  # :nodoc:
  def has_key? key
    respond_to? key.intern
  end
  
  def __index(key)
    send key.intern
  end
  
  def do_thing haystack, k, v, fullname, fullname_str
    message = ""
    # get key
    if !haystack.has_key?(k)
      if v
        message += "Missing from actual: #{fullname_str} => #{v.inspect}\n"
      end
    else
        # inspect key
      # if we are looking for a collection
      if v.kind_of?(Hash) || v.kind_of?(Array)
        # and the haystack has a collection
        if !(haystack.__index(k).kind_of?(String) || haystack.__index(k).kind_of?(TrueClass) || haystack.__index(k).kind_of?(FalseClass) || haystack.__index(k).kind_of?(Fixnum) || haystack.__index(k).kind_of?(Bignum))
          # recurse if both are collections
          message += v.compare_includes?(haystack.__index(k),fullname)
          
          # otherwise, complain that we aren't the same
        else
          message += "Difference: required <#{fullname_str} => #{v.inspect}> was <#{fullname_str} => #{haystack.__index(k).inspect}>\n" 
        end
        
        # if we aren't looking for a collection, see if we aren't the same
      else
        haystack_value = haystack.__index(k)
        if (haystack_value.kind_of? Array and
              haystack_value.length == 1)
          haystack_value = haystack_value.first
        end
        if (haystack_value != v)
          message += "Difference: required <#{fullname_str} => #{v.inspect}> was <#{fullname_str} => #{haystack_value.inspect}>\n" 
        end
      end
    end
    message
  end
end
  
  class Hash  # :nodoc:
    def __index(key)
	self[key]
    end

    def compare_includes? haystack, prefix=[]
        message = ""
	# check that haystack is the same type?

	# iterate over your self (particular to self)
	self.each do |k,v|

	    # make a sensible name for each element of the needle (particular to self)
	    fullname = prefix.clone.push k
	    fullname_str = fullname.join(".")
	    
	    message += do_thing(haystack, k, v, fullname, fullname_str)
	end
	
        message
    end
end

module Test  # :nodoc: all
  module Unit 
    module Assertions 
      def assert_includes needle, haystack, message=""
        _wrap_assertion {
          message = needle.compare_includes?( haystack )
          unless( message == "")
            flunk(message.chomp)
          end
        }
      end
    end
  end
end

