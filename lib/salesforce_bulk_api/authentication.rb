require 'oauth2'
require 'socket'

module SalesforceBulkApi
	attr_accessor :oauth_client
	attr_accessor :options
  
  class Authentication

  	def initialize(options = {})
  	  @options = options
  	  @options.symbolize_keys!
	  end

	  def get_token
			@oauth_client = OAuth2::Client.new(
				@options[:client_id],
				@options[:client_secret],
				:site => "https://#{@options[:host]}",
				:authorize_url => '/services/oauth2/authorize',
				:token_url => '/services/oauth2/token'
			)
			@oauth_client.password.get_token(@options[:username], @options[:password])
	  end

	  private

	  def host_name
	  	host_name = ENV['ORIGIN']
	  	if host_name.nil? || host_name.strip.empty?
	  		get_host_name = Socket.gethostname
	  	  host_name = URI.parse(get_host_name.gsub(/\?.*$/,''))     
	  	  host_name = host_name.to_s
	  	end
	  	return host_name
	  end
	end
end