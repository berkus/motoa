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
require 'settings'
require 'searcher'

class SearchTermsDialog < Qt::Dialog

  slots 'dosearch()'

  def initialize(parent)
    super(parent, Qt::WA_DeleteOnClose)
    setModal(true)
    setWindowTitle("Enter search terms, each on new line")

    Qt::VBoxLayout.new(self)

    @terms_input = Qt::TextEdit.new(self)
    days_label = Qt::Label.new("Days:", self)
    @days_input = Qt::LineEdit.new(self)
    @ok_btn = Qt::PushButton.new("Go", self)

    hbox = Qt::HBoxLayout.new(self)
    hbox.addWidget(days_label)
    hbox.addWidget(@days_input)
    
    layout.addWidget(@terms_input)
    layout.addItem(hbox)
    layout.addWidget(@ok_btn)

    connect(@ok_btn, SIGNAL('clicked()'), SLOT('dosearch()'))
  end

  def dosearch
    terms = @terms_input.toPlainText.strip.squeeze("\r\n")
    days = @days_input.text.to_i
    return if terms.empty? || !days.is_a?(Fixnum)

    $settings.days = days
    $settings.terms = terms
    PREFS.save
    
    @searcher = Searcher.new( terms.split("\n") )
    hide
    pbar = Qt::ProgressDialog.new( "Searching for terms..", "Abort", 0, 100, self )
    pbar.setModal(false)
    pbar.windowTitle = "Searching..."
    results = @searcher.query(days, pbar)
    pbar.close

    e = parent.centralWidget
    e.setHtml("")
    e.setUpdatesEnabled(false)
    tmpl = IO.readlines("list.template").join("\n")

    p "Populating html..."
    pbar = Qt::ProgressDialog.new( "Reading in results..", "Abort", 0, results.size, self )
    pbar.windowTitle = "Please wait"
    step = 0
    results.each { |key,res|
      pbar.setValue(step)
      step += 1
      $qApp.processEvents

      source_url = key
      source     = res[:source]
      date       = res[:date]
      file       = res[:filename]
      title      = res[:title]
      is_new     = res[:fresh] ? "NEW" : ""
      out = tmpl.gsub("{source_url}", source_url).gsub("{source}", source).gsub("{date}", date).gsub("{file}", file).gsub("{title}", title).gsub("{is_new}", is_new)
      e.append(out)
    }
    e.setUpdatesEnabled(true)
    pbar.close
    p "Done."
    self.reject
  end

end
