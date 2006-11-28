class StrScanParserR # :nodoc:
    def initialize scanner
	@scanner = scanner
    end
    
    def match regex, &block
	if s = @scanner.scan(regex)
	 #   $stderr.puts "got: #{s}"
	    yield @scanner if block
	    s
	else
	  #  $stderr.puts "tried #{regex.source} on: #{@scanner.rest}"
	    nil
	end
    end

    def rest?
	@scanner.rest?
    end

    def rest
	@scanner.rest
    end
end
