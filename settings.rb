class Settings
  attr_reader :days, :terms, :override, :perpage, :limit, :concurrency, :loglevel, :basedir

  def initialize(name)
      @basedir = File::basename(name, ".conf")
      @terms = []
      @days = 2
      @limit = 500
      @override = false
      @perpage = 200
      @concurrency = 3
      @loglevel = Logger::INFO
      readterm = false
      IO.readlines(name).each { |line|
         if line =~ /^===+/
           readterm = true
           next
         end
         if readterm
            inp = line.strip
            if inp =~ /^(\*+)(.+)$/
              @terms << { :term => $2.strip, :importance => $1.size }
            else
              @terms << { :term => inp, :importance => 0 }
            end
         else
            if line =~ /^days:\s*(\d+)/i # number of days to look back
               @days = $1.to_i
            end
            if line =~ /^limit:\s*(\d+)/i # max number of entries
               @limit = $1.to_i
            end
            if line =~ /^override:\s*(yes|true|1)$/i # override the search to return all results again
               @override = true
            end
            if line =~ /^perpage:\s*(\d+)/i # number of links on single index page
               @perpage = $1.to_i
            end
            if line =~ /^concurrency:\s*(\d+)/i # number of threads fetching pages concurrently
               @concurrency = $1.to_i
            end
            if line =~ /^loglevel:\s*(\S+)/i # debug info level, Logger::NN
              case $1.downcase
              when 'fatal'
                @loglevel = Logger::FATAL
              when 'error'
                @loglevel = Logger::ERROR
              when 'warn'
                @loglevel = Logger::WARN
              when 'info'
                @loglevel = Logger::INFO
              when 'debug'
                @loglevel = Logger::DEBUG
              else
               raise "Unknown log level #{$1}"
              end
            end
         end
      }
  end

  def outfile(n = 0)
      File.join(@basedir, File::Separator, "#{@basedir}_#{n}.html") # FIXME will fail if basedir contains fullpath!!
  end
end
