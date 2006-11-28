module Web
  class Wiki
  class Linker #:nodoc:
    def initialize
    end

    def html_regexp
      /((<textarea)(.)*(\/textarea>))|(<a[ ]*href=[\"']*([^\"'>]*)[\"']*>([^(<\/)]*)<\/a>)|(<[^>]*>)/mi #"'
    end
    
    def scan_linked_word( scanner , output )
      if scanner.scan(/\[\[(.*?)\]\]/)
        if Web::Wiki.page_list.include?(scanner[1])
          output.print "<a href=\"?page.name=#{Web::escape(scanner[1])}\">#{scanner[1]}</a>"
        else
          output.print "#{scanner[1]}<a href=\"?page.name=#{Web::escape(scanner[1])}&action=edit\">?</a>"
        end
        true
      else
        false
      end
    end
    
    def make_link( pagename )
      if (Web::Wiki::pref( :script_url ) && Web::Wiki::pref( :store_url ) )
        "<a href=\"#{Web::Wiki::pref(:script_url)}/#{pagename}.html\">#{pagename}</a>"
      else
        "<a href=\"?page.name=#{Web::escape(pagename)}\">#{pagename}</a>"
      end
    end
    
    def scan_bumpy_word( scanner , output )
      if scanner.scan(/([A-Z][\w\/]*[a-z][\w\/]*[A-Z]\w*)/)
        if Web::Wiki.page_list.include?(scanner[1])
          output.print make_link( scanner[1] )
        else
          output.print "#{scanner[1]}<a href=\"?page.name=#{Web::escape(scanner[1])}&action=edit\">?</a>"
        end
        true
      else
        false
      end
    end
    
    def scan_html( scanner , output )
      if scanner.scan(html_regexp)
        output.print scanner[0]
        true
      else
        false
      end
    end
    
    def scan_other( scanner , output )
      if scanner.scan(/(\w+|\s+|.)/)
        output.print scanner[1]
        true
      else
        false
      end
    end
    
    def replace_links(string )
      out = StringIO.new
      scanner = StringScanner.new(string)
      while scan_linked_word( scanner , out ) || scan_bumpy_word( scanner , out ) || scan_html( scanner , out ) || scan_other( scanner , out )
      end
      out.string
    end
  end
end
end
