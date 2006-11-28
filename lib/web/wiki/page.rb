module Web
  class Wiki

    #begin experiment with SimpleDispatcher
    class PageEditor #:nodoc: # < Web::SimpleDispatcher::Template
                     include Web::SimpleDispatcher::TemplateMixin##
      
      class << self
        include Web::SimpleDispatcher::TemplateClassMixin
      end
      
      
      attr_accessor :page, :wiki
      
      def page
        unless @page
          @page = wiki.load_page
          unless (Web["revision"] == nil || Web["revision"].empty? || Web["revision"].to_s == "0")
            history = @page.history
            @page = history.find{ |p|
              Web["revision"].to_i == p.revision
            }
            @page.history = history
          end
        end
        @page
      end
      
      
      def initialize
      end
      
      def on_submit r
        page.set_automatic_fields
        wiki.save( page )
      end
    end
    # end experiment with SimpleDispatcher

  class Page #:nodoc:
    @@attributes = []
    def Page.page_attr( *symbols )
      symbols.each { |symbol|
        attr_accessor symbol
        @@attributes.push symbol
      }
    end
  
    @@max_revisions = 25
    def Page.max_revisions
      @@max_revisions
    end
    
    def set_by_request
      @@attributes.each { |symbol|
        self.send( symbol.to_s + "=", Web["page." + symbol.to_s] )
      }
      set_automatic_fields
    end

    def set_automatic_fields
      self.revision += 1
      self.mtime = Time.now()
      self.history.unshift self.clone
      self.history.pop if ( self.history.size > Page.max_revisions )
      self.remote_addr = ENV["REMOTE_ADDR"]
    end
    
    attr_accessor :name, :revision, :history, :mtime, :remote_addr
    page_attr :content, :align, :valign, :illustration, :bg_color, :text_color, :top_margin, :left_margin, :comment
    def initialize( name )
      self.name = name
      self.revision = 0
      self.history = [ ]
      self.content = ""
      self.comment = ""
      self.illustration = ""
      self.bg_color = "ffffff"
      self.text_color = "000000"
      self.align = "left"
      self.valign = "top"
      self.top_margin = "5"
      self.left_margin = "5"
      self.mtime = Time.now()
      self.remote_addr = "auto-create"
    end
    
    def mtime_pretty
      if (mtime.hour > 12)
        mtime.hour - 12
    elsif (mtime.hour == 0)
        12
      else
        mtime.hour
      end.to_s + ":" +
          mtime.min.to_s +
                mtime.strftime("%p ").downcase +
    mtime.strftime("%b ") +
          mtime.mday.to_s +
                mtime.strftime( ", %Y" )
    end
    
    def template
      if (self.name == Web::Wiki::pref(:home_page))
        Web::Wiki::pref( :home_template )
      elsif(self.illustration == nil)
        "basic.html"
      elsif (self.illustration.empty?)
        "basic.html"
      else
        "illustration.html"
      end
    end

    def escaped_name
      name.gsub( /\//, "-slash-" )
    end
  
    def download_link
      File.join( Web::Wiki.store_url, escaped_name, "" )
    end

    def dir
      File.join( Web::Wiki.store_dir, escaped_name )
    end

    class Asset < String #:nodoc:
      attr_accessor :owner
      def initialize(newowner, newpath)
        self.owner = newowner
        super( newpath )
      end

      def size
        File.size( File.join( owner.dir, self ) )
      end

      def thumbnail
        if (size > 102400)
          "#{self} (<i>#{size} bytes</i>)"
        else
          "<img src='#{owner.download_link}#{self}' border=0 width=100><br>#{self}"
        end
      end

    end

    def assets
      a = if (File.exists? dir)
            (Dir.entries( dir ) - [".", ".."]).find_all { |e|
              e =~ /^[^\#]/
            }.collect{ |e|
              Asset.new(self, e)
            }
          else
            [ ]
          end
      a
    end
    
    def historical_assets
      historical = {}
      assets.each { |e|
        historical[e] = Dir[dir + "/*" + e].entries.sort { |a,b|
          File.mtime( a ) <=> File.mtime( b )
        }.collect { |e|
          File.basename(e)
        }
      }
      Dir[dir + "/\#*deleted.*"].entries.each{ |e|
        base = File.basename(e).gsub( /\#(\d+\.){0,1}deleted\./, "" )
        historical[base] = [ File.basename(e) ] unless historical.has_key?( base )
      }
      historical
    end
    
    # this method must be after the page_attr :content call
    def content=( newcontent )
      {
        %r{(<[^>]*)(http:\/\/[^"']*)(((#{Regexp.escape(download_link)})|(#{Regexp.escape(download_link.gsub(/&/, "&amp;"))}))[^"']*)(((\s|'|")[^>]*>)|>)} => '\1\3\7',
    }.each{ |pattern, replacement|
        newcontent.gsub!( pattern, replacement )
      }
      @content = newcontent
    end
    
    def html
      Web::Wiki::Linker.new.replace_links(self.content)
    end
  end
  end
end   
