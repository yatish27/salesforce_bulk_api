require 'yaml'
require 'databasedotcom'

describe SalesforceBulkApi do

  before :each do
    auth_hash = YAML.load(File.read('auth_credentials.yml'))
    @sf_client = Databasedotcom::Client.new(:client_id => auth_hash['salesforce']['client_id'],
                 :client_secret => auth_hash['salesforce']['client_secret'])
    @sf_client.authenticate(:username => auth_hash['salesforce']['user'], :password => auth_hash['salesforce']['passwordandtoken'])
    @api = SalesforceBulkApi::Api.new(@sf_client)
  end

  describe 'upsert' do
    pending
  end

  describe 'update' do
    pending
  end

  describe 'create' do
    pending
  end

  describe 'delete' do
    pending
  end
  
  describe 'query' do
  
    it 'returns the query results' do
      res = @api.query('Account', 'SELECT * From Account')
      res.records.should_be > 1
    end
  
  end

end