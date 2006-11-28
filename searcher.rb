############################################################################
#    Copyright (C) 2006 by Stanislav Karchebny                             #
#    stanislav.karchebny@skype.net                                         #
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
$LOAD_PATH.unshift './lib'
require 'cgi'
require 'mechanize'
require 'iconv'

class Searcher

  def initialize(terms)
    @terms = terms.split("\n")
    p "Searching for #{@terms.size} terms"
  end

  def query
    agent = WWW::Mechanize.new
    agent.user_agent = 'TaramParam/1.0.0; berkus@madfire.net'

    now = Time.now
    twodaysago = now - 3600*48

    @terms.each { |term|
      page = agent.get("http://news.yandex.ru/yandsearch?rpt=nnews2&date=within&text=#{CGI.escape(Iconv.new('cp1251', 'utf8').iconv(term))}&within=777&from_day=#{twodaysago.day}&from_month=#{twodaysago.month}&from_year=#{twodaysago.year}&to_day=#{now.day}&to_month=#{now.month}&to_year=#{now.year}&numdoc=500&Done=%CD%E0%E9%F2%E8&np=1")

      File.open("result_#{term.gsub(" ", "_")}.page", "w") { |f|
        f.puts page.body
      }
    }
    p "Query complete"
    GC.start
  end

end

