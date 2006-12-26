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
require 'thread'

def doiconv(term)
  if /win|mingw/ =~ RUBY_PLATFORM
    term
  else
    Iconv.conv('cp1251', 'UTF-8', term)
  end
end


class Searcher

  def initialize(terms, basedir, override = false)
    @terms = terms
    @base = basedir
    @override = override # if true, ignore the fact that we already found some news on previous runs and return them now
    log_info "Searching for #{@terms.size} terms"

    FileUtils.mkdir_p(@base)
    FileUtils.mkdir_p(filepath('pages'))
    FileUtils.mkdir_p(filepath('debug.querypages'))
    FileUtils.mkdir_p(filepath('results'))
  end

  def filepath(name)
    File.join(@base, File::SEPARATOR, name)
  end

  def query(days, limit, concurrency, pbar)
    agent = WWW::Mechanize.new
    agent.user_agent = 'TaramParam/1.0.0; berkus@madfire.net'

    output_results = {}

    results = {} # declare var
    begin
      File.open(filepath("article.index"), "r") { |f|
        results = Marshal::load(f)
      }
    rescue Errno::ENOENT
      results = {}
    end

    pbar.show
    termstep = 0

    now = Time.now
    daysago = now - days*3600*24

    @terms.each { |hashterm|
      term = doiconv(hashterm[:term])
      # use open-uri's URI because uri's parse chokes on escaped chars.
      page = agent.get(URI("http://news.yandex.ru/yandsearch?rpt=nnews2&date=within&text=#{CGI.escape(term)}&within=777&from_day=#{daysago.day}&from_month=#{daysago.month}&from_year=#{daysago.year}&to_day=#{now.day}&to_month=#{now.month}&to_year=#{now.year}&numdoc=#{limit}&Done=%CD%E0%E9%F2%E8&np=1"))

      File.open(filepath("debug.querypages/#{term.gsub(" ", "_")}_#{Time.now.to_s.gsub(/[ +:-]/, "_")}"), "w") { |ff|
         ff.puts page.body
      }

      # grab data between <ol start="1" class="results"> and </ol>
      subpage = page.search('ol.results > li')

      step = 0
      pbar.setRange(step, subpage.size)
      termstep += 1
      pbar.setLabelText("Searching for terms #{termstep}/#{@terms.size}..")

      # Fetch pages concurrently in several threads
      fetchQueue = SizedQueue.new concurrency
      ioMutex = Mutex.new
      saveMutex = Mutex.new
      Thread.abort_on_exception = false
      subpage.each { |pg|
        GC.start
        fetchQueue << pg # will block when max concurrency threads are created
        log_debug "Pushed to fetchQueue (in main thread)"
        Thread.new(pg) {|pg|
          Thread.current[:fetcher] = true # mark thread as fetcher
          ioMutex.synchronize {
            pbar.setValue(step)
            pbar.windowTitle = "Fetching (#{step}/#{subpage.size})"
            $qApp.processEvents
            step += 1 # increment should be synchronized as well
          }

          link = pg.search('span > a[@href]')

          url = link[0].get_attribute('href')
          title = link.inner_html.strip
          date = pg.search('span.date').inner_html.gsub("&nbsp;", " ")
          source = pg.search('span.source').inner_html
          excerpt = pg.search('div').inner_html

          if date =~ /^\d\d:\d\d$/ # only time
            date = DateTime.now
          else
            date = begin
                    DateTime::strptime(date, "%d.%m.%y %H:%M")
                  rescue ArgumentError
                    date
                  end
          end

          unless results[url]
            results[url] = {}
            results[url][:source] = source
            results[url][:title] = title
            results[url][:excerpt] = excerpt
            results[url][:date] = date
            results[url][:fetch_date] = DateTime.now
            results[url][:search_term] = [term]
            results[url][:importance] = hashterm[:importance]

            log_info "fetching #{url} (in #{Thread.current})"
            filename = filepath("pages/"+Digest::MD5.hexdigest(url)+".html")
            results[url][:filename] = filename
            results[url][:downloaded] = true

            begin
              data = open(URI(url)) #agent.get fails in hpricot on aspx pages - _why promised to fix in 0.6
            rescue Timeout::Error
              log_error "fetch timeout for #{url} (in #{Thread.current})"
              results[url][:filename] = url
              results[url][:downloaded] = false
            rescue
              log_error "fetch error for #{url} (in #{Thread.current})"
              results[url][:filename] = url
              results[url][:downloaded] = false
            else
              File.open(filename, "w") { |of|
                of.puts "<!-- saved from #{url} on #{Time.now.to_s} -->"
                of.puts data.read
              }
              log_info "fetched #{url} (in #{Thread.current})"
            end
            # add newly found stuff to output
            output_results[url] = results[url]
            log_debug "added #{url} to query results (in #{Thread.current})"
          else
            # We have this url, but probably on different search term
            results[url][:search_term] << term unless results[url][:search_term].include? term
            results[url][:excerpt] += "<br />" + excerpt unless results[url][:excerpt].include? excerpt
            results[url][:importance] = hashterm[:importance] if hashterm[:importance] > results[url][:importance]
            # add already existing stuff to output only when overriding
            if @override
              output_results[url] = results[url]
              log_debug "overriding: added #{url} to query results even tho it was previously found (in #{Thread.current})"
            end
          end

          saveMutex.synchronize {
            File.open(filepath("article.index"), "w") { |file|
              Marshal::dump(results, file) # save after each iteration
            }
          }
          log_debug "Popping from fetchQueue (in #{Thread.current})"
          fetchQueue.pop # let main thread push more fetching threads
        } # Thread
      }
      Thread.list.each { |t| t.join if t[:fetcher] == true }
      log_info "Term query complete"
    }
    log_info "Full query complete"
    output_results
  end

end

