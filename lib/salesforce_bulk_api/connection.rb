module SalesforceBulkApi
require 'timeout'

  class Connection
    include Concerns::Throttling
    attr_reader :api_version

    @@XML_HEADER = '<?xml version="1.0" encoding="utf-8" ?>'
    @@LOGIN_HOST = 'login.salesforce.com'
    @@INSTANCE_HOST = nil # Gets set in login()

    def initialize(client)
      @client=client
      @session_id = nil
      @server_url = nil
      @instance = nil
      @api_version = determine_api_from_client(client) 
      @@LOGIN_PATH = "/services/Soap/u/#{@api_version}"
      @@PATH_PREFIX = "/services/async/#{@api_version}/"

      login()
    end

    def determine_api_from_client(client)
      client_type = @client.class.to_s
      case client_type
      when "Restforce::Data::Client"
        return client.options.fetch(:api_version,"32.0") # returns 32.0 if no api_version
      when "Databasedotcom::Client"
        return client.version
      else
        raise TypeError, "Client must be a restforce or databasedotcom client."
      end
    end

    def login()
      client_type = @client.class.to_s
      case client_type
      when "Restforce::Data::Client"
        @session_id=@client.options[:oauth_token]
        @server_url=@client.options[:instance_url]
      else
        @session_id=@client.oauth_token
        @server_url=@client.instance_url
      end
      @instance = parse_instance()
      @@INSTANCE_HOST = "#{@instance}.salesforce.com"
    end

    def post_xml(host, path, xml, headers)
      host = host || @@INSTANCE_HOST
      if host != @@LOGIN_HOST # Not login, need to add session id to header
        headers['X-SFDC-Session'] = @session_id
        path = "#{@@PATH_PREFIX}#{path}"
      end
      i = 0
      begin
        count :post
        throttle(http_method: :post, path: path)
        https(host).post(path, xml, headers).body
      rescue
        i += 1
        if i < 3
          puts "Request fail #{i}: Retrying #{path}"
          retry
        else
          puts "FATAL: Request to #{path} failed three times."
          raise
        end
      end
    end

    def get_request(host, path, headers)
      host = host || @@INSTANCE_HOST
      path = "#{@@PATH_PREFIX}#{path}"
      if host != @@LOGIN_HOST # Not login, need to add session id to header
        headers['X-SFDC-Session'] = @session_id;
      end

      count :get
      throttle(http_method: :get, path: path)
      https(host).get(path, headers).body
    end

    def https(host)
      req = Net::HTTP.new(host, 443)
      req.use_ssl = true
      req.verify_mode = OpenSSL::SSL::VERIFY_NONE
      req
    end

    def parse_instance()
      @instance = @server_url.match(/https:\/\/[a-z]{2}[0-9]{1,2}/).to_s.gsub("https://","")
      @instance = @server_url.split(".salesforce.com")[0].split("://")[1] if @instance.nil? || @instance.empty?
      return @instance
    end

    def counters
      {
        get: get_counters[:get],
        post: get_counters[:post]
      }
    end

    private

    def get_counters
      @counters ||= Hash.new(0)
    end

    def count(http_method)
      get_counters[http_method] += 1
    end

  end

end
