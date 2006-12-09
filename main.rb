$KCODE='u'
require 'Qt'
require 'motoa.rb'

a = Qt::Application.new( ARGV )
mw = Motoa.new
mw.windowTitle = "MotoAnalysis"
mw.show
a.connect( a, SIGNAL('lastWindowClosed()'), a, SLOT('quit()') )
a.exec
