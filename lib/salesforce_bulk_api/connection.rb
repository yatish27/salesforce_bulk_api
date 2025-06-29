require "timeout"
require "net/https"

module SalesforceBulkApi
  class Connection
    include Concerns::Throttling

    LOGIN_HOST = "login.salesforce.com".freeze

    attr_reader :session_id, :server_url, :instance, :instance_host

    def initialize(api_version, client)
      @client = client
      @api_version = api_version
      @path_prefix = "/services/async/#{@api_version}/"
      @counters = Hash.new(0)

      login
    end

    def post_xml(host, path, xml, headers)
      host ||= @instance_host
      headers["X-SFDC-Session"] = @session_id unless host == LOGIN_HOST
      path = "#{@path_prefix}#{path}" unless host == LOGIN_HOST

      perform_request(:post, host, path, xml, headers)
    end

    def get_request(host, path, headers)
      host ||= @instance_host
      path = "#{@path_prefix}#{path}"
      headers["X-SFDC-Session"] = @session_id unless host == LOGIN_HOST

      perform_request(:get, host, path, nil, headers)
    end

    def counters
      {
        get: @counters[:get],
        post: @counters[:post]
      }
    end

    private

    def login
      client_type = @client.class.to_s
      @session_id, @server_url = if client_type == "Restforce::Data::Client"
        [@client.options[:oauth_token], @client.options[:instance_url]]
      else
        [@client.oauth_token, @client.instance_url]
      end
      @instance = parse_instance
      @instance_host = "#{@instance}.salesforce.com"
    end

    def perform_request(method, host, path, body, headers)
      retries = 0
      begin
        count(method)
        throttle(http_method: method, path: path)
        response = https(host).public_send(method, path, body, headers)
        response.body
      rescue => e
        retries += 1
        if retries < 3
          puts "Request fail #{retries}: Retrying #{path}"
          retry
        else
          puts "FATAL: Request to #{path} failed three times."
          raise e
        end
      end
    end

    def https(host)
      Net::HTTP.new(host, 443).tap do |http|
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
    end

    def count(http_method)
      @counters[http_method] += 1
    end

    def parse_instance
      instance = @server_url.match(%r{https://([a-z]{2}[0-9]{1,2})\.})&.captures&.first
      instance || @server_url.split(".salesforce.com").first.split("://").last
    end
  end
end
