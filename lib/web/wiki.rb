require 'web'
require 'web/wiki/linker'
require 'web/wiki/page'
require 'yaml'
require 'ftools'
require 'strscan'
require 'ipaddr'

module Web
  # == Purpose
  # This wiki exists to:
  #     * Serve http://www.narf-lib.org
  #     * Test the utility of features in the NARF toolkit, and serve
  #       as an example of how to build a decent-sized application
  #       with NARF
  #     * Be a nice, useful wiki; aka UseMod with HTMLArea integration
  #       and image uploads
  #
  # == Usage
  # This is the quickest way to embed the narf wiki:
  #
  #    #!/usr/bin/env ruby
  #    require 'web/wiki'
  #    Web::process{
  #      Web::Wiki::handle_request()
  #    }
  # 
  # You will enjoy your wiki more, however, by fiddling with
  # a few config settings. Here what a production wiki.rb might
  # look like:
  #
  #    #!/usr/bin/env ruby
  #    require 'web/wiki'
  #    
  #    Web::process{
  #      # this line allows me to overload the default templates
  #      Web::template_include_path << "../"
  #
  #      # here I set a number of config variables.
  #      Web::Wiki::set_pref( :store_url  => "/pages/",
  #                           :store_dir  => "../pages/",
  #                           :home_page  => "NarfRocks",
  #                           :resourceurl => "/resources" )
  #
  #      # finally, I handle the request
  #      Web::Wiki.handle_request
  #    }
  #
  # The default templates for the NARF wiki are located in
  #
  #     site_lib/web/wiki/resources/
  # 
  # Append your template dir to the template_include_path and
  # only worry about overriding the templates you care about.
  # Chances are, you'll care about these two templates:
  # 
  # template.html:: the overall template
  # home.html:: the template for the  homepage
  # 
  # The following preferences can make a difference for
  # your wiki:
  #
  # store_dir::
  #     Web::Wiki uses YAML to save pages.  By default,
  #     these pages will be saved in "./pages/".
  # store_url::
  #     If you make your store files publicly accessible,
  #     Web::Wiki can let the webserver handle any the download
  #     of any upload page assets.
  # home_page::
  #     The default home page for the wiki is HomePage.  Set the
  #     HomePage to something meaningful in your wiki.
  # resourceurl::
  #     By default, the NARF wiki will download various resource files
  #     from sitelib/web/wiki/resources.  This makes installation easy,
  #     but a single visit to the edit page will incur the hit of
  #     executing ruby for every single image.  Make these files
  #     accessible online and tell NARF where to find them, and
  #     things should run more quickly.
  # 
  # == Credits
  # Web::Wiki must extend its thanks to these very, very useful projects:
  #
  # YAML:: http://yaml4r.sourceforge.net/
  # HTMLArea:: http://sourceforge.net/projects/itools-htmlarea/
  #
  class Wiki

    # It seems nicer to define the class
    # methods on an object and
    # delegate a few class methods
    def Wiki.method_missing( symbol, *args )
      if [:handle_request,
          :store_dir,
          :store_url,
          :store_basedir,
          :more_news,
          :page_list,
          :exit_handler ].include? symbol 
        wiki.send symbol, *args
      else
        super( symbol, args )
      end
    end
    
    @@wiki = nil
    def Wiki.wiki
      @@wiki ||= Wiki.new
    end
    
    def Wiki.wipe #:nodoc:
      @@wiki = nil
    end
    
    @@preferences = nil
    def Wiki.preferences
      @@preferences ||= {"baseurl" => Web::script_name,
                         "resourceurl" => "{$baseurl}/resources",
                         "store_dir" => "./pages/",
                         "tarpit_dir" => "./tarpit/",
                         "resource_dir" => File.join( File.dirname( __FILE__ ),
                                                      "wiki",
                                                      "resources" ),
                         "vandals" => "vandals.txt",
                         "home_page" => "HomePage",
                         "home_template" => "home.html",
                         "allowed_actions" => Wiki::Request.actions.keys
      }
    end

    def Wiki.pref( key )
      key = key.to_s unless (key.kind_of? String)
      pref = Wiki.preferences[key]
      while (pref =~ /\{\$([^\}]*)\}/)
        variable = $1
        pref.gsub!( /\{\$#{variable}\}/, Wiki.pref( variable.strip ) || "")
      end
      pref
    end

    def Wiki.set_pref( new_prefs={} )
      new_prefs.each{ |key,value|
        key = key.to_s unless (key.kind_of? String) 
        Wiki.preferences[key] = value
      }
    end
    #-------------------------------------------------------------
    
    module Store #:nodoc:
      
      def move_asset( from, filename )
        historical = File.expand_path(filename)
        i=0
        while( File.exists? historical )
          i += 1
          historical = File.dirname( historical ) + "/\#" + i.to_s + "." + File.basename( historical ).gsub( /^\#\d*\./, "" )
        end
        
        File.move( filename, historical ) if File.exists? filename

        if (from.is_a? Web::Upload)
          from.write_to_file(filename)
        else
          File.move( from, filename )
        end
      end
      
      def page_list
        Dir[store_dir + "/*.yaml"].entries.collect { |e|
          File.basename( e, ".yaml" ).gsub( /-slash-/, "/" )
        }
      end
      
      def store( name )
        File.join( store_dir, name.gsub(/\//, "-slash-") + ".yaml" )
      end
      
      def load_page( name = Web["page.name"] )
        if name.size == 0
          if (Web.path_info)
            name = Web.path_info.gsub( Regexp.new(Web.script_name), "" ).gsub(/^\/|\.html$/,"")
          end
          if name.size == 0
            name = Web::Wiki::pref( :home_page )
          end
        end
        
        page = ""
        page_file = store( name )
        if File.exists? page_file
          File.open( page_file, "r" ) { |f|
            page = YAML.load( f )
          }
        else
          page = Web::Wiki::Page.new( name )
        end
        
        {/\\r/ => "\r",
         /\\n/ => "\n",
         /\\"/ => "\"",
         /\\'/ => "'",  }.each{ |find, replace|
          page.content.gsub!( find, replace )
        }
        page
      end
      
      def news
        more_news[0..4]
      end
      
      def more_news
        if File.exists?(store_dir + "/more_news.yaml")
          contents = File.open( store_dir + "/more_news.yaml" ) { |f| f.read }
          unless contents.empty?
            YAML.load(contents)
          else
            [ ]
          end
        else
          [ ]
        end
      end
      
      def save( page )
        # save a slim version of the page for recent changes
        rcpage = page.clone
        rcpage.content = ""
        rcpage.history = [ ]
        rc = more_news
        rc = rc.unshift(rcpage) unless rcpage.comment.empty?
        rc.pop if rc.size > Page::max_revisions
        
        yaml = rc.to_yaml
        File.open( store_dir + "/more_news.yaml", "w" ) { |f|
          f.write(yaml)
        }
        
        comment = page.comment
        # clear out comment now that we've saved more news
        page.comment = ""
        yaml = page.to_yaml
        File.open( store( page.name ), "w" ) { |f|
          f.write(yaml)
        }
      end
      

      def store_basedir
        if ( vandal? )
          Wiki.pref( "tarpit_dir" )
        else
          Wiki.pref( "store_dir" )
        end
      end

      def store_dir
        unless (File.exists? store_dirname)
          File.makedirs( store_dirname)
        end
        store_dirname
      end

      def store_url
        Wiki::pref( :store_url ) || Wiki::pref( :store_dir )
      end
      
      def store_dirname
        unless ( store_basedir =~ /^(\w:)?\// )
          File.expand_path( Dir.pwd + "/" + self.store_basedir )
        else
          store_basedir
        end
      end

      def vandal?
        vandal = false
        vandals.each do |pattern|
          if pattern =~ ENV["REMOTE_ADDR"]
            vandal = true
            break
          end
        end
        vandal
      end
      
      def vandals
        @vandals ||= if File.exists?( Wiki.pref("vandals") || "" )
                       File.open( Wiki.pref("vandals") ) { |f|
                         f.to_a
                      }.collect{ |line|
                         /^#{line.chomp.strip.gsub(/"/, '')}/
                      }
                     else
                       [ ]
                     end
      end
      
      def exit_handler
        require 'find'
        Find.find( store_dir ) { |name|
          begin
            if File.directory? name
              File.chmod( 0777, name )
            else
              File.chmod( 0666, name )
            end
          rescue Exception
            # this should be more specific to access errors
          end
        }
      end

    end
    
    include Wiki::Store
    
    #-------------------------------------------------------------

    def handle_request
      Request.new( self ).handle_request
      unless (Wiki.pref("added_exit_handler"))
        exit_handler
        Wiki.set_pref("added_exit_handler" => true )
      end
    end
    
    class Request # :nodoc:
      
      attr_accessor :page, :template, :content_template, :vars, :wiki
      
      def initialize( wiki )
        @handled = false
        @wiki = wiki
        @template = if (File.basename(Web.script_name || '') == "admin.rb")
                      "admin.html"
                    else
                      "template.html"
                    end
      end
      
      def page
        unless @page
          @page = self.wiki.load_page
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
      
      def vars
        @vars ||= {"page"    => self.page,
                   "wiki"    => self.wiki,
                   "action"  => Web["action"],
                   "baseurl" => Web::Wiki::pref(:baseurl),
                   "resourceurl" => Web::Wiki::pref(:resourceurl),
        }
      end
      
      def handle_request
        cmd = Web["action"]
        cmd = "default" if cmd.empty? || cmd == "view_revision"
        cmd = "download_resource" if Web::path_info =~ /^\/resources\//
        cmd = "default" unless Web::Wiki::pref("allowed_actions").include?(cmd)
        
        Request.actions[cmd].call(self)
        
        
        unless @handled
          Web.template_include_path << Web::Wiki::pref("resource_dir")
          self.vars["content_template"] = self.content_template
          Web.print_template( self.template, self.vars ) if self.template
          @handled = true
        end
      end
      
      @@actions = {}
      def Request.actions
        @@actions
      end
      
      def Request.action( name, &action )
        Action.new name, &action
      end

      
      class Action #:nodoc:
        attr_accessor :name
        def initialize( name, &action )
          @name = name
          @action = action
          Request.actions[name] = self
        end
        
        def call( request )
          if (self.name == "default")
            request.content_template = request.page.template
          else
            request.content_template = self.name + ".html"
          end
          @action.call(request) if @action
          if ( [ "illustration.html",
                "images.html" ].include? request.content_template )
            request.template = request.content_template
          end
        end
      end
      
      [ "default", "page_history", "images", "more_news" ].each{ |boring_action|
        action( boring_action )
      }
      
      #action( "more_news_rss_0.91" ) {|r|
      #  r.template = "more_news_rss_0.91.html"
      #}
      
      action( "edit" ) { |r|
        r.page.comment = "";
        r.vars["options"] = {
          "content_editor" => case ENV["HTTP_USER_AGENT"]
                              when /MSIE.*Windows/
                                "ie-content_editor.html"
                              when /Mozilla.*(?!MSIE).*Windows/
                                "ekit-content_editor.html"
                              else
                                "default-content_editor.html"
                              end,
                             "page_types" => ["Normal", "Illustration"],
                                                                     "align"      => ["left", "center", "right"],
                                                                                                              "valign"     => ["top",  "middle", "bottom"],
        }
      }
      
      def download_file( basedir, requested_asset )
        self.template = nil
        self.content_template = nil

        basedir = File.expand_path( basedir )
        requested_asset = File.expand_path( File.join(basedir,
                                                      requested_asset.gsub( /\\/, "/") ) )
        # security check on the requested_asset --
        # it must be underneath the basedir
        if ( requested_asset.index( basedir ) == 0 && \
             File.exists?( requested_asset ) )
          # deliver the file
          Web.content_type = Web.get_mime_type( requested_asset )
          Web.write File.open(requested_asset, "r" ) { |f|
            f.read
          }
          Web.flush
        else
          Web.status = "404";
          Web.write "404 File Not Found"
          Web.flush
        end
      end
      
      action( "download" ) { |r|
        r.download_file( r.page.dir,Web["asset"] )
      }
      
      action("download_resource") { |r|
        r.download_file( Wiki::pref(:resource_dir),
                         Web::path_info.gsub( /^\/resources/, '' ) )
      }
    
      

      ["select_illustration", "insert_download"].each{ |images_target|
        action(images_target) { |r|
          r.template = "images.html"
        }
      }

      action( "Upload" ) { |r|
        r.content_template = "images.html"
        r.vars["action"] = Web["calling_action"]
        Dir.mkdir r.page.dir unless (File.exists? r.page.dir)
        r.wiki.move_asset( Web["upload"],
                           File.join( r.page.dir,
                                      File.basename(Web["upload"]                 \
                                                    .original_filename            \
                                                    .gsub( /\\/, "/") ) ) )
      }
      
      action( "asset_history" ) { |r|
        r.vars["asset"] = { "name" => Web["asset"],
                           "history" => r.page.historical_assets[Web["asset"]] }
      }
      
      action( "Save" ) { |r|
        # patrick's (seemed simpler at the moment)
        # comment out if you want to try the
        # simple dispatcher code below
        r.page.set_by_request
        r.wiki.save( r.page )

        # redirect back to default
        Web::multiple_params["action"] = ["default"]
        Web::clear()
        r.handle_request
      }
      
      

      action( "delete_asset" ) { |r|
        r.content_template = "images.html"
        r.vars["action"] = Web["calling_action"]
        r.wiki.move_asset( File.join( r.page.dir, File.basename( Web["asset"] ) ),
                           File.join( r.page.dir, File.basename( "\#deleted." + Web["asset"] ) ) )
      }
      
    end
    
  end
end
