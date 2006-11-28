module Web
    class CGI
	def CGI.trace_output_template
	    template = <<-EOF
<div>
<h1>Request Details</h1><br>
<table cellspacing="0" cellpadding="0" border="1" style="width:100%;border-collapse:collapse;">
<tr>
  <th class="alt" align="Left" colspan=2><h3><b>Request Parameters</b></h3></th></tr>
  <narf:foreach from=parameters item=parameter>
    <tr><th width=150>{$parameter.key}</th><td>{$parameter.value}</td></tr>
  </narf:foreach>
</table>
<br>
<table cellspacing="0" cellpadding="0" border="1" style="width:100%;border-collapse:collapse;">
  <tr><th class="alt" align="Left" colspan=2><h3><b>Cookies</b></h3></th></tr>
  <narf:foreach from=cookies item=cookie>
    <tr><th  width=150>{$cookie.key}</th><td>{$cookie.value}</td></tr>
  </narf:foreach>
</table>
<br>
<table cellspacing="0" cellpadding="0" border="1" style="width:100%;border-collapse:collapse;">
  <tr><th class="alt" align="Left" colspan=2><h3><b>Session</b></h3></th></tr>
  <narf:foreach from=session item=sessionitem>
    <tr><th  width=150>{$sessionitem.key}</th><td>{$sessionitem.value}</td></tr>
 </table>
</div>
EOF
        end
    end
end

