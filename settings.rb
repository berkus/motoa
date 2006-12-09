$LOAD_PATH.unshift("lib")
require 'preferences'

PREFS = Preferences.new('batch.ini')

class Settings
  attr_accessor :days, :terms
  
  def initialize
    PREFS.register "batch" do |entry|
      entry.var "terms"
      entry.var "days" => 2
    end
  end
  
  def cleanup
    PREFS.save
  end
end

$settings = Settings.new
