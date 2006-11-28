Struct.new("Tag",:name,:attributes)
Tag = Struct::Tag

class StrScanParser < StrScanParserR #:nodoc:

    TAG_START = /<narf:/
    TAG_END = />/
    TAG_CLOSE_START = /<\/narf:/
    TAG_NAME = /(\w+)/
    WHITESPACE = /\s*/
    QUOTE = /"/
    QUOTED_ATTRIBUTE_VALUE = /([^"?]+)/
    UNQUOTED_ATTRIBUTE_VALUE = /([\w.\/\$?]+)/
    EQUALS = /=/
    ATTRIBUTE_NAME = /(\w+)/
    
    def match_value 
	if @scanner.scan(QUOTE)
	    if @scanner.scan(QUOTED_ATTRIBUTE_VALUE)
		yield @scanner[1]
		@scanner.scan(QUOTE) || raise(MissingQuoteException.new)
	    end
	elsif @scanner.scan(UNQUOTED_ATTRIBUTE_VALUE)
	    yield @scanner[1]
	end
    end
    
    def match_attribute
	if @scanner.scan(ATTRIBUTE_NAME)
	    name = @scanner[1]
	    if @scanner.scan(EQUALS)
		match_value do |value|
		    yield({ name => value })
		end || raise(MissingAttributeException.new)
	    else
		yield({ name => nil })
	    end
	end 
    end
    
    def match_tag
	if @scanner.scan(TAG_START)
	    name = ""
	    nvs = {}
	    if @scanner.scan(TAG_NAME)
		name = @scanner[1]
		while true
		    @scanner.scan(WHITESPACE)
		    match_attribute do |nv|
			nvs.update(nv)
		    end || if @scanner.scan(TAG_END)
			       yield Tag.new(name,nvs)
			       return true
			   else 
			       raise(TagNotClosedException.new)
			   end
		end
	    else
		raise(TagNotNamedException.new)
	    end
	end
    end

    def match_close_tag
	if @scanner.scan(TAG_CLOSE_START)
          tag = nil
          if @scanner.scan(TAG_NAME) 
            tag = @scanner[1]
          end # TODO raise missing name exception
          @scanner.scan(TAG_END) # TODO raise missing end tag exception
          yield tag if tag
	end
    end
    
    def match_identifier
	if @scanner.scan(/\{\$([\w.\?]*?)\}/)
            yield @scanner[1]
        end
    end
end

class MissingAttributeException < Exception # :nodoc:

end

class TagNotClosedException < Exception # :nodoc:
    
end

class TagNotNamedException < Exception # :nodoc:
    
end

class MissingQuoteException < Exception # :nodoc:
    
end
