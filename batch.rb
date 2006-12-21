unless ARGV.size > 0
  puts "usage: batch.rb configfilename"
  exit
end

$KCODE='u'
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

config = Settings.new(ARGV[0])
search = Searcher.new(config.terms)
pbar = FakePbar.new
results = search.query(config.days, pbar)

html = IO.readlines("html.header").join rescue ""
tmpl = IO.readlines("html.template").join

p "Populating html..."
results.sort { |a,b| a[1][:search_term].size <=> b[1][:search_term].size }.each { |key,res|
  source_url = key
  source     = res[:source]
  date       = res[:date]
  file       = res[:filename]
  title      = res[:title]
  excerpt    = res[:excerpt]
  is_new     = res[:fresh] ? "NEW" : ""
  terms      = res[:search_term].join("|")
  out = tmpl.gsub("{source_url}", source_url) \
            .gsub("{source}", source) \
            .gsub("{date}", date) \
            .gsub("{file}", file) \
            .gsub("{title}", title) \
            .gsub("{excerpt}", excerpt) \
            .gsub("{is_new}", is_new) \
            .gsub("{terms}", terms)
  html << out
}
html << IO.readlines("html.footer").join

File.open(config.outfile, "w") { |f|
  f.puts html
}

`start #{config.outfile}`
