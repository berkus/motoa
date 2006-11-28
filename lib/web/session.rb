require 'digest/md5'
module Web
  # == Purpose
  # Provides a file based implemetation of a session.
  # This is hacked up from matz's CGI::Session
  class Session
	

	class << self
	    def create_id
		md5 = Digest::MD5.new
		md5.update( String(Time.now.to_f) )
		md5.update( String(rand(0))  ) 
		#md5.update( String($$)       )
		#md5.update( 'thanks matz'    )
		md5.hexdigest[0,16]
	    end
	end

	def initialize( cgi, options={} )
	    @session_id = load_id( cgi, options )

	    send_cookie( cgi, options[:session_key] || "_session_id" )

	    @session = get_session_from_disk
	end

	def get_session_from_disk
	    if File.exists? file
		File.open( file, "r" ) { |store|
		    Marshal.load store
		}
	    else
		{}
	    end
	end

	def load_id( cgi, options )
	    if (options.has_key? :session_id)
		options[:session_id]
	    elsif(cgi.cookies["_session_id"] && !cgi.cookies["_session_id"].empty?)
		cgi.cookies["_session_id"][0]
	    else
		Session.create_id
	    end
	end
	    

	def send_cookie( cgi, session_key )
	    cgi.set_cookie( session_key, @session_id )
	end


	# saves session to disk
	def save
	    File.open( file, "w+" ) { |store|
		Marshal.dump( @session, store )
	    }
	end

	def temp_dir
	  temp = ENV['TMP'] || ENV['TEMP'] || '/tmp'
	  unless( File.exists? temp )
	    temp = "c:/windows/temp"
	  end
	  temp
	end

	def file
	    File.expand_path(File.join(self.temp_dir, File.basename(@session_id.to_s).untaint))
	end
	
	# resets session to empty hash, for use in testing
	def reset
	    @session = {}
	end
	
	def method_missing(method, *args, &block)
	    # much faster than simple delegator
	    @session.send(method,*args,&block)
	end
    end
end
