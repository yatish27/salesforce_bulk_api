require 'spec_helper'
require 'yaml'
require 'databasedotcom'

describe SalesforceBulkApi do

  before :each do
    auth_hash = YAML.load(File.read('auth_credentials.yml'))
    @sf_client = Databasedotcom::Client.new(:client_id     => auth_hash['salesforce']['client_id'],
                                            :client_secret => auth_hash['salesforce']['client_secret'])
    @sf_client.authenticate(:username => auth_hash['salesforce']['user'], :password => auth_hash['salesforce']['passwordandtoken'])
    @api = SalesforceBulkApi::Api.new(@sf_client)
  end

  describe 'upsert' do
    
    context 'when not passed get_result' do
      it "doesn't return the batches array" do
        res = @api.upsert('Account', [{:Id => '0013000000ymMBh', :Website => 'www.test.com'}], 'Id')
        res['batches'].should be_nil
      end
    end
    
    context 'when passed get_result = true' do
      it 'returns the batches array' do
        res = @api.upsert('Account', [{:Id => '0013000000ymMBh', :Website => 'www.test.com'}], 'Id', true)
        res['batches'][0]['response'].is_a? Array
        res['batches'][0]['response'][0].should eq({'id'=>['0013000000ymMBhAAM'], 'success'=>['true'], 'created'=>['false']})
      end
    end
    
    context 'when passed send_nulls = true' do
      it 'sets the nil and empty attributes to NULL' do
        @api.update('Account', [{:Id => '0013000000ymMBh', :Website => 'abc123', :Other_Phone__c => '5678'}], 'Id', true)
        res = @api.query('Account', "SELECT Website, Other_Phone__c From Account WHERE Id = '0013000000ymMBh'")
        res['batches'][0]['response'][0]['Website'][0].should eq 'abc123'
        res['batches'][0]['response'][0]['Other_Phone__c'][0].should eq '5678'
        res = @api.upsert('Account', [{:Id => '0013000000ymMBh', :Website => '', :Other_Phone__c => nil}], 'Id', true, true)
        res['batches'][0]['response'][0].should eq({'id'=>['0013000000ymMBhAAM'], 'success'=>['true'], 'created'=>['false']})
        res = @api.query('Account', "SELECT Website, Other_Phone__c From Account WHERE Id = '0013000000ymMBh'")
        res['batches'][0]['response'][0]['Website'][0].should eq({"xsi:nil" => "true"})
        res['batches'][0]['response'][0]['Other_Phone__c'][0].should eq({"xsi:nil" => "true"})
      end
    end
  end

  describe 'update' do
    context 'when there is not an error' do
      context 'when not passed get_result' do
        it "doesnt return the batches array" do
          res = @api.update('Account', [{:Id => '0013000000ymMBh', :Website => 'www.test.com'}])
          res['batches'].should be_nil
        end
      end
  
      context 'when passed get_result = true' do
        it 'returns the batches array' do
          res = @api.update('Account', [{:Id => '0013000000ymMBh', :Website => 'www.test.com'}], true)
          res['batches'][0]['response'].is_a? Array
          res['batches'][0]['response'][0].should eq({'id'=>['0013000000ymMBhAAM'], 'success'=>['true'], 'created'=>['false']})
        end
      end
    end
    
    context 'when there is an error' do
      context 'when not passed get_result' do
        it "doesn't return the results array" do
          res = @api.update('Account', [{:Id => '0013000000ymMBh', :Website => 'www.test.com'},{:Id => 'abc123', :Website => 'www.test.com'}])
          res['batches'].should be_nil
        end
      end
  
      context 'when passed get_result = true with batches' do
        it 'returns the results array' do
          res = @api.update('Account', [{:Id => '0013000000ymMBh', :Website => 'www.test.com'}, {:Id => '0013000000ymMBh', :Website => 'www.test.com'}, {:Id => '0013000000ymMBh', :Website => 'www.test.com'}, {:Id => 'abc123', :Website => 'www.test.com'}], true, false, 2)
          res['batches'][0]['response'].should eq([{"id"=>["0013000000ymMBhAAM"], "success"=>["true"], "created"=>["false"]}, {"errors"=>[{"fields"=>["Id"], "message"=>["Account ID: id value of incorrect type: abc123"], "statusCode"=>["MALFORMED_ID"]}], "success"=>["false"], "created"=>["false"]}])
          res['batches'][1]['response'].should eq([{"id"=>["0013000000ymMBhAAM"], "success"=>["true"], "created"=>["false"]},{"id"=>["0013000000ymMBhAAM"], "success"=>["true"], "created"=>["false"]}])
        end
      end
    end
    
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
        res = @api.query('Account', "SELECT id, Name From Account WHERE Name LIKE 'Test%'")
        res['batches'][0]['response'].length.should > 1
        res['batches'][0]['response'][0]['Id'].should_not be_nil
      end
      context 'and there are multiple batches' do
        it 'returns the query results in a merged hash' do
          pending 'need dev to create > 10k records in dev organization'
          res = @api.query('Account', "SELECT id, Name From Account WHERE Name LIKE 'Test%'")
          res['batches'][0]['response'].length.should > 1
          res['batches'][0]['response'][0]['Id'].should_not be_nil
        end
      end
    end
  
    context 'when there are no results' do
      it 'returns nil' do
        res = @api.query('Account', "SELECT id From Account WHERE Name = 'ABC'")
        res['batches'][0]['response'].should eq nil
      end
    end
    
    context 'when there is an error' do
      it 'returns nil' do
        res = @api.query('Account', "SELECT id From Account WHERE Name = ''ABC'")
        res['batches'][0]['response'].should eq nil
      end
    end
    
  end

end
