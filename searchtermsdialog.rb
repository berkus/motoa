############################################################################
#    Copyright (C) 2006 by Stanislav Karchebny   #
#    stanislav.karchebny@skype.net   #
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
require 'searcher'

class SearchTermsDialog < Qt::Dialog

  slots 'dosearch()'

  def initialize(parent)
        super( parent, "Search Terms", false, WDestructiveClose )

        Qt::VBoxLayout.new(self)

        @terms_input = Qt::TextEdit.new(self)
        @ok_btn = Qt::PushButton.new("Go", self)

        layout.add(@terms_input)
        layout.add(@ok_btn)

        connect(@ok_btn, SIGNAL('clicked()'), SLOT('dosearch()'))
  end

  def dosearch
    return if @terms_input.text.strip.empty?
    @searcher = Searcher.new( @terms_input.text )
    pbar = Qt::ProgressDialog.new( "Searching for terms..", "Abort", 1, self, nil, false )
    @searcher.query(pbar)
  end

end
