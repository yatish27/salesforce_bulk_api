module SalesforceBulkApi
require 'timeout'

  class Connection
    include Concerns::Throttling

    LOGIN_HOST = 'login.salesforce.com'

    def initialize(api_version, client)
      @client = client
      @api_version = api_version
      @path_prefix = "/services/async/#{@api_version}/"

      login()
    end

    def login()
      client_type = @client.class.to_s
      case client_type
      when "Restforce::Data::Client"
        @session_id = @client.options[:oauth_token]
        @server_url = @client.options[:instance_url]
      else
        @session_id = @client.oauth_token
        @server_url = @client.instance_url
      end
      @instance = parse_instance()
      @instance_host = "#{@instance}.salesforce.com"
    end

    def post_xml(host, path, xml, headers)
      host = host || @instance_host
      if host != LOGIN_HOST # Not login, need to add session id to header
        headers['X-SFDC-Session'] = @session_id
        path = "#{@path_prefix}#{path}"
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
      host = host || @instance_host
      path = "#{@path_prefix}#{path}"
      if host != LOGIN_HOST # Not login, need to add session id to header
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

    #Edited by AD to include scenarios where the domain name is something like 'ab12cdef' and the salesforce instance url is 'ab12cdef.my.salesforce.com'.
    #In that case, as per the original case, the @instance variable will evaluate to 'ab12.salesforce.com' instead of 'ab12cdef.my.salesforce.com'.
    #That would lead to this error --> "Failed to open TCP connection to ab12.salesforce.com:443 (getaddrinfo: Name or service not known)".
    #In the following lines of code, we are checking to see if there is a '.' following the earlier regex to ensure that its not some fancy custom domain name.

      @instance = @server_url.match(/https:\/\/[a-z]{2}[0-9]{1,2}\./).to_s.gsub("https://","").split(".")[0]
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
