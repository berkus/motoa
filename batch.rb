unless ARGV.size > 0
  puts "usage: batch.rb configfilename"
  exit
end

$KCODE='u'
require 'thread'
require 'logger'
require 'searcher'
require 'settings'

# fake entities
class QApp
  def processEvents
  end
end
$qApp = QApp.new

class FakePbar
  attr_accessor :windowTitle
  def initialize
  end
  def setRange(a,b)
  end
  def setValue(v)
  end
  def setLabelText(t)
  end
  def show
  end
  def hide
  end
end

$config = Settings.new(ARGV[0])

FileUtils.mkdir_p($config.basedir)

# Set up logging
$logout = Logger.new(File.join($config.basedir, File::SEPARATOR, "run.log"), 'monthly')
$logout.level = $config.loglevel
$logout.progname = 'Batch'
$log_mutex = Mutex.new
def log_debug msg
  $log_mutex.synchronize { $logout.debug msg }
end
def log_info msg
  $log_mutex.synchronize { $logout.info msg }
end
def log_warn msg
  $log_mutex.synchronize { $logout.warn msg }
end
def log_error msg
  $log_mutex.synchronize { $logout.error msg }
end
def log_fatal msg
  $log_mutex.synchronize { $logout.fatal msg }
end

search = Searcher.new($config.terms, $config.basedir, $config.override)
pbar = FakePbar.new
results = search.query($config.days, $config.limit, $config.concurrency, pbar)

html = ""
tmpl = IO.readlines("html.template").join

def weighted_sort(a, b)
  $config.terms.size * a[:importance] + a[:search_term].size <=> $config.terms.size * b[:importance] + b[:search_term].size
end

log_info "Populating html... (#{results.size} results)"
tally = 0
itemcount = 0
pagecount = 0
results.sort { |a,b| weighted_sort(b[1], a[1]) }.each { |key,res| # reverse sort!
  if itemcount == 0
    html = IO.readlines("html.header").join
    html.gsub!("{start}", (tally+1).to_s)
  end

  source_url = key
  source     = res[:source]
  date       = if res[:date].respond_to? :strftime
                  res[:date].strftime("%Y.%m.%d")
               else
                  res[:date]
               end
  file       = res[:filename]
  title      = res[:title]
  excerpt    = res[:excerpt]
  terms      = res[:search_term].join("|")
  entryclass = "block"
  entryclass = "multi" if res[:search_term].size > 1
  entryclass = "highlight" if res[:importance] > 0
  entryclass = "broken" if !res[:downloaded]
  out = tmpl.gsub("{source_url}", source_url) \
            .gsub("{source}", source) \
            .gsub("{date}", date) \
            .gsub("{file}", file) \
            .gsub("{title}", title) \
            .gsub("{excerpt}", excerpt) \
            .gsub("{entryclass}", entryclass) \
            .gsub("{terms}", terms)
  html << out

  # paginate output
  itemcount += 1
  tally += 1
  if itemcount >= $config.perpage || tally == results.size
    if pagecount > 0
      html << "<div class='navback'><a href='#{File::basename($config.outfile(pagecount-1))}'>&lt;&lt;&lt;</a></div>"
    end
    if tally < results.size
      html << "<div class='navfore'><a href='#{File::basename($config.outfile(pagecount+1))}'>&gt;&gt;&gt;</a></div>"
    end

    html << IO.readlines("html.footer").join
    File.open($config.outfile(pagecount), "w") { |f|
      f.puts html
    }
    itemcount = 0
    pagecount += 1
  end
}

$logout.close

if /win|mingw/ =~ RUBY_PLATFORM
  `start #{$config.outfile}`
else
  `kfmclient openURL #{$config.outfile}`
end
