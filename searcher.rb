############################################################################
#    Copyright (C) 2006 by Stanislav Karchebny                             #
#    berkus@madfire.net                                                    #
#                                                                          #
#    This program is free software; you can redistribute it and#or modify  #
#    it under the terms of the GNU General Public License as published by  #
#    the Free Software Foundation; either version 2 of the License, or     #
#    (at your option) any later version.                                   #
#                                                                          #
#    This program is distributed in the hope that it will be useful,       #
#    but WITHOUT ANY WARRANTY; without even the implied warranty of        #
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
#    GNU General Public License for more details.                          #
#                                                                          #
#    You should have received a copy of the GNU General Public License     #
#    along with this program; if not, write to the                         #
#    Free Software Foundation, Inc.,                                       #
#    59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             #
############################################################################
require 'rubygems'
require 'cgi'
require 'mechanize'
require 'iconv'
require 'open-uri'
require 'digest/md5'

def doiconv(term)
#  Iconv.conv('cp1251', 'UTF-8', term)
  term
end


class Searcher

  def initialize(terms)
    @terms = terms
    p "Searching for #{@terms.size} terms"
  end

  def query(days, pbar)
    agent = WWW::Mechanize.new
    agent.user_agent = 'TaramParam/1.0.0; berkus@madfire.net'

    results = {} # declare var
    begin
      File.open("article.index", "r") { |f|
        results = Marshal::load(f)
      }
    rescue Errno::ENOENT
      results = {}
    end

    pbar.show
    termstep = 0

    now = Time.now
    daysago = now - days*3600*24

    @terms.each { |term|
      term = doiconv(term)
      # use open-uri's URI because uri's parse chokes on escaped chars.
      page = agent.get(URI("http://news.yandex.ru/yandsearch?rpt=nnews2&date=within&text=#{CGI.escape(term)}&within=777&from_day=#{daysago.day}&from_month=#{daysago.month}&from_year=#{daysago.year}&to_day=#{now.day}&to_month=#{now.month}&to_year=#{now.year}&numdoc=500&Done=%CD%E0%E9%F2%E8&np=1"))

      File.open("debug.querypages/#{term.gsub(" ", "_")}_#{Time.now.to_s.gsub(/[ +:-]/, "_")}", "w") { |ff|
         ff.puts page.body
      }

      # grab data between <ol start="1" class="results"> and </ol>
      subpage = page.search('ol.results > li')

      step = 0
      pbar.setRange(step, subpage.size)
      termstep += 1
      pbar.setLabelText("Searching for terms #{termstep}/#{@terms.size}..")

      subpage.each { |pg|
        GC.start
        pbar.setValue(step)
        pbar.windowTitle = "Fetching (#{step}/#{subpage.size})"
        $qApp.processEvents
        step += 1

        link = pg.search('span > a[@href]')

        url = link[0].get_attribute('href')
        title = link.inner_html.strip
        date = pg.search('span.date').inner_html
        source = pg.search('span.source').inner_html
        excerpt = pg.search('div').inner_html

        unless results[url]
          p "fetching #{url}"
          filename = "pages/"+Digest::MD5.hexdigest(url)+".html"
          begin
            data = open(URI(url)) #agent.get fails in hpricot on aspx pages - _why promised to fix in 0.6
          rescue Timeout::Error
            p "timed out"
            next
          rescue OpenURI::HTTPError
            p "http error"
            next
          # rescue ERRNO::EBADF
	  rescue
	    p "Unknown error"
	    next
          end
          File.open(filename, "w") { |of|
            of.puts "<!-- saved from #{url} on #{Time.now.to_s}-->"
            of.puts data.read
          }

          results[url] = {}
          results[url][:source] = source
          results[url][:title] = title
          results[url][:excerpt] = excerpt
          results[url][:date] = date
          results[url][:fresh] = true
          results[url][:filename] = filename
          results[url][:search_term] = [term]
          p "done"
        else
          # We have this url, but probably on different search term
          results[url][:search_term] << term unless results[url][:search_term].include? term
        end

        File.open("article.index", "w") { |file|
          Marshal::dump(results, file) # save after each iteration
        }
      }
    }
    p "Query complete"
    results.select { |k,r| r[:fresh] == true }
  end

end

