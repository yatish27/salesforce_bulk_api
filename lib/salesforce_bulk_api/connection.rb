require 'timeout'

module SalesforceBulkApi
  class Connection
    include Concerns::Throttling

    LOGIN_HOST = 'login.salesforce.com'
    RESTFORCE_CLIENT_TYPE = 'Restforce::Data::Client'

    def initialize(api_version, client)
      @client = client
      @api_version = api_version
      @path_prefix = "/services/async/#{@api_version}/"

      login
    end

    def login
      @client_type = @client.class.to_s

      case @client_type
      when RESTFORCE_CLIENT_TYPE
        # authenticate the client if it's not already authenticated
        @client.authenticate! if @client.options[:oauth_token].empty? || @client.options[:instance_url].empty?

        @session_id = @client.options[:oauth_token]
        @server_url = @client.options[:instance_url]
      else
        @session_id = @client.oauth_token
        @server_url = @client.instance_url
      end

      @instance = parse_instance
      @instance_host = "#{@instance}.salesforce.com"
    end

    def reauthenticate
      # currently only supports Restforce reauthentication
      @client.authenticate! if @client_type == RESTFORCE_CLIENT_TYPE
      login
    end

    def post_xml(host, path, xml, headers)
      retried = false
      begin
        host = host || @instance_host
        if host != LOGIN_HOST # Not login, need to add session id to header
          headers['X-SFDC-Session'] = @session_id
          path = "#{@path_prefix}#{path}"
        end

        count :post
        throttle(http_method: :post, path: path)
        response = https(host).post(path, xml, headers).body
        raise if response.code == '401'

        response
      rescue
        raise if retried

        retried = true
        reauthenticate
        retry
      end
    end

    def get_request(host, path, headers)
      retried = false
      begin
        host = host || @instance_host
        path = "#{@path_prefix}#{path}"
        if host != LOGIN_HOST # Not login, need to add session id to header
          headers['X-SFDC-Session'] = @session_id;
        end

        count :get
        throttle(http_method: :get, path: path)
        response = https(host).get(path, headers).body
        raise if response.code == '401'

        response
      rescue
        raise if retried

        retried = true
        reauthenticate
        retry
      end
    end

    def https(host)
      req = Net::HTTP.new(host, 443)
      req.use_ssl = true
      req.verify_mode = OpenSSL::SSL::VERIFY_NONE
      req
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

    def parse_instance
      @instance = @server_url.match(/https:\/\/[a-z]{2}[0-9]{1,2}\./).to_s.gsub("https://","").split(".")[0]
      @instance = @server_url.split(".salesforce.com")[0].split("://")[1] if @instance.nil? || @instance.empty?
      @instance
    end
  end
end
