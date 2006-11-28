
class Date # :nodoc: 
  def _dump(limit) Marshal.dump([@rjd, @sg], -1) end
  def self._load(str) new0(*Marshal.load(str)) end
end    

def encode64(bin) # :nodoc:
   [bin].pack("m").gsub(/\n/,'').gsub(/=/,'.')
end

def decode64(str) # :nodoc:
   str.gsub(/\./,'=').unpack("m")[0]
end


module Web
    module Request         # :nodoc
	def Request.typed_params params
	    params2 = {}
	    params.collect do |k,v|
		if ! (k =~ /type/)
		    if (atype = params["#{k}-type"][0]) 
			begin
			    params2[k] = eval(Web.unescape(atype)).unencode(v[0])
			rescue
			    params2[k] = eval(Web.unescape(atype)).unencode(Web.unescape(v[0]))
			end
		    else
			if v[0].kind_of? String
			    params2[k] = v[0]
			else
			    params2[k] = v[0]
			end
		    end
		end
	    end
	    params2
	end

	def Request.parse_typed_params query_string
	    Request.typed_params(Web::Request.parse_query_string(query_string))
	end
    end

    class << self
	def encode_objects hash
	    newhash = {}
	    hash.each do |k,v|
		v = ([] << v).flatten
		v.each { |v|
		    if v.kind_of?(String)
			newhash[k] = v
		    elsif 
			newhash[k] = Web.escape(v.encode)
			newhash["#{k}-type"] = v.class.name
		    end
		}
	    end
	    newhash
	end

	def typed_params
	    $__web__cgi.typed_params
	end
    end
        
    class CGI
	def typed_params
	    Request.typed_params multiple_params
	end

	def make_query_string params
	    params.collect do |a,b|
		"#{a}=#{Web.escape(b)}"
	    end.join("&")
	end
	
	def query
	    if Web["__submitted"] != ""
		aquery = {}
		typed_params.each do |k,v|
		    if k =~ /^__q\.(.+)/
			aquery[$1] = v
		    end
		end
		aquery
	    else
		typed_params
	    end
	end
	
	def reset_headers
	    @headers_sent = false
	end

	def script_path
	    if m = /(.*)\//.match(Web.get_cgi.script_name)
		$1
	    else
		""
	    end
	end
    end
end
