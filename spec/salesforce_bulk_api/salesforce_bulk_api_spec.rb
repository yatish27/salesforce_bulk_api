require 'spec_helper'
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
    
    context 'when not passed get_result' do
      it 'doesnt return the results array' do
        res = @api.upsert('Account', [{:Id => '0013000000ymMBh', :Website => 'www.test.com'}], 'Id')
        res['result'].should be_nil
      end
    end
    
    context 'when passed get_result = true' do
      it 'returns the results array' do
        res = @api.upsert('Account', [{:Id => '0013000000ymMBh', :Website => 'www.test.com'}], 'Id', true)
        res['result'].is_a? Array
        res['result'][0].should eq({'id'=>['0013000000ymMBhAAM'], 'success'=>['true'], 'created'=>['false']})
      end
    end
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
  
    context 'when there are results' do
      it 'returns the query results' do
        res = @api.query('Account', "SELECT id, Name From Account WHERE Name LIKE '%Test%'")
        res['result'].length.should > 1
        res['result'][0]['Id'].should_not be_nil
      end
    end
  
    context 'when there are no results' do
      it 'returns nil' do
        res = @api.query('Account', "SELECT id From Account WHERE Name = 'ABC'")
        res['result'].should eq nil
      end
    end
    
    context 'when there is an error' do
      it 'returns nil' do
        res = @api.query('Account', "SELECT id From Account WHERE Name = ''ABC'")
        res['result'].should eq nil
      end
    end
    
  end

end