module Web
  class Action #:nodoc:
    attr_reader :patterns
    def initialize patterns={}, &function
      @patterns = patterns
      @function = function || lambda{}
      Thread.current[:actions] ||= [ ]
      Thread.current[:actions].push self
    end

    def run cgi=Web::CGI.create
      @function.call( cgi )
    end
    
    def old_applies? cgi
      matches = false
      patterns.each{ |key, pattern|
        cgi.multiple_params[key].each{ |value|
          if pattern.kind_of? Regexp
            matches = true if value =~ pattern
          else
            matches = true if value == pattern
          end
        }
      }
      matches
    end

    def applies? cgi
      relevance = 0;
      unmatched_terms = patterns.size;
      patterns.each{ |key, pattern|
        if pattern.kind_of? Regexp
          if cgi.multiple_params[key].find{ |value| value =~ pattern }
            unmatched_terms = unmatched_terms - 1
            relevance += 1
          end
        else
          if cgi.multiple_params[key].find{ |value| value == pattern }
            unmatched_terms = unmatched_terms - 1
            relevance += 10
          end
        end
      }
      if unmatched_terms == 0
        relevance
      else
        false
      end
    end
    
    def Action.pick( cgi )
      Thread.current[:actions] ||= [ ]
      Thread.current[:actions].find_all do |action|
        action.applies? cgi
      end.sort do |a, b|
        a.applies?(cgi) <=> b.applies?(cgi)
      end.last || Thread.current[:actions].find do |action|
        action.patterns == {}
      end || blank_action
      
      #	    (raise Web::Exception.new( "Could not locate action for #{ cgi.multiple_params.inspect }" ))
    end
    
    def Action.blank_action
      blank = Action.new
      Thread::current[:actions].delete blank
      blank
    end

    def Action.run options={}
      if options.kind_of? Hash
        Web.process(options) do |cgi|
          pick(cgi).run(cgi)
        end
      elsif options.kind_of? Web::CGI
        pick(options).run(options)
        options.close
        options
      end
    end
  end
end
