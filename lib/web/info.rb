module Web
  @@message_template = nil

  def Web::print_message( title, content )
    @@message_template ||=
             lib_file_contents('resources/message_template.html' )
    Web::puts( @@message_template.gsub( /\$title\$/,
                                        title ).gsub( /\$content\$/,
                                                      content ) )
  end

  def Web::info_fileinfo( file)
    lines = '<table>'
    %w!original_filename read content_type!.each { |m|
      lines << "<tr><td>#{m}</td><td>#{file.send(m)}</td></tr>"
    }
    lines << '</table>'
  end
    


  def Web::info
    Web::clear()
    case Web["test"]
    when "multipart.html"
      Web::puts <<-EOF
<html>
<head>
<title>test for multipart/formdata</title>
</head>
<body>

<form method="post" enctype="multipart/form-data" action="test_install.cgi">
<input type="hidden" name="test" value="multipart">

<ul>
<li>files
<ul>
<li><input type="file" name="file1"></li>
<li><input type="file" name="file2"></li>
</ul>
</li>

<li>textinput
<ul>
<li><input type="text" name="text1" value="Text 1"></li>
<li><input type="text" name="text2" value="Text 2"></li>
</ul>
</li>

<li>checkbox
<ul>
<li><input type="checkbox" name="checkbox1" value="Checkbox 1">1</li>
<li><input type="checkbox" name="checkbox1" value="Checkbox 2">2</li>
<li><input type="checkbox" name="checkbox1" value="Checkbox 3" checked>3</li>
</ul>
</li>

<li>radio button
<ul>
<li><input type="radio" name="radio1" value="Radio 1-1">1-1</li>
<li><input type="radio" name="radio1" value="Radio 1-2" checked>1-2</li>
<li><input type="radio" name="radio1" value="Radio 1-3">1-3</li>
<li><input type="radio" name="radio2" value="Radio 2-1">2-1</li>
<li><input type="radio" name="radio2" value="Radio 2-2">2-2</li>
<li><input type="radio" name="radio2" value="Radio 2-3" checked>2-3</li>
</ul>
</li>

<li>text area
<ul>
<li><textarea name="textarea1">Text Area 1</textarea></li>
<li><textarea name="textarea2">Text Area 2</textarea></li>
</ul>

<li>selections
<ul>
<li>
<select name="select1">
  <option value="a">A</option>
  <option>B</option>
</select>
</li>
<li>
<select name="select2">
  <option value="aa">AA</option>
  <option selected>BB</option>
</select>
</li>
</ul>
</li>

</ul>

<div>
<input type="submit" name="submit" value="submit">
</div>

</form>

</body>
</html>
EOF

  when "multipart"
    begin
      Web << '<h1>result</h1>'
      Web << Web::info_fileinfo( Web['file1']) + '<hr>'
      Web << Web::info_fileinfo( Web['file2']) + '<hr>'
      Web << '<table border>'
      %w!text1 text2 checkbox1 radio1 radio2 textarea1 textarea2 select1 select2!.each { |k|
        Web << "<tr><td>#{k}</td><td>#{Web[k]}</td></tr>"
      }
      Web << '</table>'
    rescue Exception
      Web << 'error:'
      Web << $!.to_s
    end
    
  when "cookie"
    if Web.key?( 'key' ) && Web['key'] != '' && Web.key?( 'value' )
      Web.set_cookie( Web['key'], Web['value'] )
    end
    
    Web << '<html><head><title>WebUnit::Cookies</title></head>'
    Web <<  '<body><h1>WebUnit::Cookies</h1><table border=1>'

    Web << Web.cookies.keys.collect{|key|
      if key == ''
        nil
      else
        "<tr><td>#{key}</td><td>#{Web.cookies[key]}</td></tr>"
      end
    }.compact.to_s
    
    Web << '</table><br>'
    
    Web << 'Params<table border=1>'
    
    Web << Web.keys.collect{|key|
      "<tr><td>#{key}</td><td>#{Web[key]}</td></tr>"
    }.to_s
    
    Web << '</table>'
    
    Web << "<form>"
    Web << '<input type="hidden" name="test" value="cookie">'
    Web << 'key = <input type="text" name="key" value="" size="20"><br>'
    Web << 'value = <input type="text" name="value" value="" size="20"><br>'
    Web << '<input type="submit">'

    Web << '</body></html>'

  when "response.html"
    Web::puts <<-EOF
<html>
<head>
  <title>WebUnit::response</title>
</head>
<body>

<h1>WebUnit::response</h1>

<hr>

<form action='simple.cgi'>

<table border=1>
  <tr><td>link</td>
      <td><a href=index-en.html>test</a></td></tr>
  <tr><td>hidden</td>
      <td>HIDDEN<input type='hidden' name='nhidden' value='HIDDEN'></td></tr>
  <tr><td>text</td>
      <td><input type='text' name='ntext' value='TEXT'></td></tr>
  <tr><td>password</td>
      <td><input type='password' name='npassword' value='PASSWORD'></td></tr>
  <tr><td>textarea</td>
      <td><textarea name='ntextarea' rows=4 cols=40>TEXTAREA
TEXTAREA</textarea></td></tr>
  <tr><td>checkbox</td>
    <td><input type='checkbox' name='ncheckbox'>
        <input type='checkbox' name='ncheckbox1' value=1 checked></td>    
  </tr>
  <tr><td>radio</td>
    <td>
      <input type='radio' name='nradio' value='a'>a,
      <input type='radio' name='nradio' value='b'>b,
      <input type='radio' name='nradio' value='c'>c
    </td>
  </tr>      
  <tr><td>combo</td>
    <td>
      <select name=nselect>
        <option value=aaa>a
        <option>b
      </select>
    </td>    
  </tr>
  <tr><td>list</td>
    <td>
      <select name=nselect1 size=5>
        <option value=aaa>a
        <option>b
        <option>c
        <option>d
      </select>
    </td>
  </tr>      
  <tr>
    <td></td>
    <td>
      <!--<input type='submit' value='SUBMIT'>-->
      <input type='submit' value='SUBMIT'>
      <input type='reset' value='RESET'>
    </td>
  </tr>
</table>

</form>

</body>
</html>
EOF
  when "redirect"
    if Web.key?( 'redirect' )
      Web.set_redirect Web['redirect']
    else
      puts( "<html><body>",
            "Use test=redirect&redirect=http://... <br>",
            "<b>" + Web::html_encode( ENV['QUERY_STRING'] || '' ) + "</b>",
            "</body></html>" )
    end
  when "stock"
    stock = ''
    
    tempfile = "/tmp/stock.cgi"

    if Web.key?( 'clear' )
      File::delete( tempfile ) if File::exist?( tempfile )
    else
      if Web.key?( 'name' ) && Web.key?( 'title' )
        open( tempfile, "a" ){ |f|
          f.puts "#{ Web.multiple_params['name'][0] },#{ Web.multiple_params['title'][0] }"
        }
      end
      if File::exist?( tempfile )
        open( tempfile ).each do |line|
          line.chop!
          stock << "<input type=\"text\" name=\"name\" value=\"#{ line.split( ',' )[0] }\">"
          stock << "<input type=\"text\" name=\"title\" value=\"#{ line.split( ',' )[1] }\">"
          stock << "<br>\n"
        end
      end
    end
    
    Web << "<html><head><title>stock.cgi</title></head><body>"
    Web << "<form method='POST'>"
    Web << "<input type=\"hidden\" name=\"test\" value=\"stock\">"
    Web << "<input type=\"text\" name=\"name\">"
    Web << "<input type=\"text\" name=\"title\">"
    Web << "<input type=\"submit\" value=\"add\">"
    Web << "<br>\n"
    Web << stock
    Web << "</form></body></html>"
  else

    
    msg = ""
    msg += "<b>" + Web.html_encode( Web.env['query_string'] || '' ) + "</b><br>"
    unless Web::params.empty?
      msg += "<h2>Web::params</h2>"
      msg += "<table onMouseover=\"changeto(event, '#F8FF80')\" onMouseout=\"changeback(event, '#eeeeff')\">"
      Web.keys.each do |key|
        msg += "<tr><td><b>#{k}:</b></td><td>#{Web::html_encode(v)}</td></tr>"
      end
      msg += "</table>"
    end
  
    msg += "<h2>Web::env</h2>"
    msg += "<table  onMouseover=\"changeto(event, '#F8FF80')\" onMouseout=\"changeback(event, '#eeeeff')\">"
    Web.env.each do |k,v|
      msg += "<tr><td><b>#{k}:</b></td><td>#{Web::html_encode(v)}</td></tr>"
    end
    msg +="</table>"
    
    Web::print_message( "Web::info", msg )
  end

end
end
