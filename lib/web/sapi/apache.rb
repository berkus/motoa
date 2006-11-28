=begin

= exteded from apache/ruby-run.rb

Copyright (C) 2001  Shugo Maeda <shugo@modruby.net>
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:
1. Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
SUCH DAMAGE.

=end

require "singleton"
require 'web'

module Web
  # === Overview
  # Web::ModNarf executes Narf scripts in Apache.
  # It is a modified version of mod_ruby's Apache::RubyRun
  #
  # == Example of httpd.conf
  #
  #   RubyRequire web/sapi/apache
  #   <Location /ruby>
  #   SetHandler ruby-object
  #   RubyHandler Web::ModNarf.instance
  #   </Location>
  class ModNarf
    include Singleton
    
    def handler(r)
      status = check_request(r)
      return status if status != Apache::OK
      filename = setup(r)
      Web::load(filename)
      return Apache::OK
    end
    
    private

    def check_request(r)
      if r.method_number == Apache::M_OPTIONS
	r.allowed |= (1 << Apache::M_GET)
	r.allowed |= (1 << Apache::M_POST)
	return Apache::DECLINED
      end
      if r.finfo.mode == 0
	return Apache::NOT_FOUND
      end
      if r.allow_options & Apache::OPT_EXECCGI == 0
	r.log_reason("Options ExecCGI is off in this directory", r.filename)
	return Apache::FORBIDDEN
      end
      unless r.finfo.executable?
	r.log_reason("file permissions deny server execution", r.filename)
	return Apache::FORBIDDEN
      end
      return Apache::OK
    end

    def setup(r)
      r.setup_cgi_env
      filename = r.filename.dup
      filename.untaint
      Apache.chdir_file(filename)
      return filename
    end
  end
end
