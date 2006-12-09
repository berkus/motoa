require 'searchtermsdialog'

class Motoa < Qt::MainWindow

  slots 'newDoc()',
        'choose()',
        'load( const QString& )',
        'save()',
        'saveAs()',
        'print()',
        'about()',
        'aboutQt()'

  def initialize()
    super
    @printer = Qt::Printer.new

    fileTools = Qt::ToolBar.new( self )

    openIcon = Qt::Pixmap.new( "fileopen.xpm" )
    fileOpen = Qt::ToolButton.new( fileTools )
    fileOpen.setIcon(Qt::Icon.new(openIcon))
    fileOpen.setText(tr("New Search"))
    connect(fileOpen, SIGNAL('clicked()'), self, SLOT('choose()'))

    printIcon = Qt::Pixmap.new( "fileprint.xpm" )
    filePrint = Qt::ToolButton.new( fileTools )
    filePrint.setIcon(Qt::Icon.new(printIcon))
    filePrint.setText(tr("Print File"))
    connect(filePrint, SIGNAL('clicked()'), self, SLOT('print()'))

    file = menuBar.addMenu( tr("&File") )
    file.addAction( tr("&New"), self, SLOT('newDoc()') ).setShortcut( Qt::KeySequence.new("Ctrl+N") )
    file.addSeparator()
    file.addAction( tr("&Print..."), self, SLOT('print()') ).setShortcut( Qt::KeySequence.new("Ctrl+P") )
    file.addSeparator()
    file.addAction( tr("&Quit"), $qApp, SLOT( 'closeAllWindows()' ) ).setShortcut( Qt::KeySequence.new("Ctrl+Q") )

    menuBar().addSeparator()

    help = menuBar.addMenu( tr("&Help") )

    help.addAction( tr("&About"), self, SLOT('about()') ).setShortcut( Qt::KeySequence.new("F1") )
    help.addAction( tr("About &Qt"), self, SLOT('aboutQt()') )

    @e = Qt::TextBrowser.new( self )
    @e.setFocus()
    setCentralWidget( @e )

    @e.setText("<html><body><h1>No items</h1></body></html>")

    statusBar().showMessage( tr("Ready"), 2000 )

    resize( 450, 600 )
  end

  private

  def newDoc()
    SearchTermsDialog.new(self).show
  end

  protected

  def closeEvent( ce )
      ce.accept()
      return
  end

  private

  def about()
      Qt::MessageBox.about( self, tr("Qt Application Example"),
                          tr("This example demonstrates simple use of " +
                          "Qt::MainWindow,\nQt::MenuBar and Qt::ToolBar."))
  end


  def aboutQt()
      Qt::MessageBox.aboutQt( self, tr("Qt Application Example") )
  end

end
