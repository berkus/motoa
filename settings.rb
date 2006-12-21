class Settings
  attr_accessor :days, :terms, :outfile
  
  def initialize(name)
      @outfile = File::basename(name, ".conf") + ".html"
      @terms = []
      @days = 2
      readterm = false
      IO.readlines(name).each { |line|
         if line =~ /^===+/
           readterm = true
           next
         end
         if readterm
            @terms << line.strip
         else
            if line =~ /^days:\s*(\d+)/
               @days = $1.to_i
            end
         end
      }
  end
end
