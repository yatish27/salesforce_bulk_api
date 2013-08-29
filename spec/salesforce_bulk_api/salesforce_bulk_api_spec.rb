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
    
    context 'when passed send_nulls = true', :focus => true do
      it 'adds fieldsToNull property' do
        expected_xml = "<?xml version=\"1.0\" encoding=\"utf-8\" ?><sObjects xmlns=\"http://www.force.com/2009/06/asyncapi/dataload\"><sObject fieldsToNull=\"['Website','Other_Phone__c']\"><Id>0013000000ymMBh</Id><Website></Website><Other_Phone__c></Other_Phone__c></sObject></sObjects>"
        @api.instance_variable_get(:@connection).should_receive(:post_xml).with(nil, "job", "<?xml version=\"1.0\" encoding=\"utf-8\" ?><jobInfo xmlns=\"http://www.force.com/2009/06/asyncapi/dataload\"><operation>upsert</operation><object>Account</object><externalIdFieldName>Id</externalIdFieldName><contentType>XML</contentType></jobInfo>", {"Content-Type"=>"application/xml; charset=utf-8"})
        XmlSimple.stub(:xml_in).and_return({'id' => ["750a0000001UizgAAC"]})
        res = @api.upsert('Account', [{:Id => '0013000000ymMBh', :Website => nil, :Other_Phone__c => nil}], 'Id', true, true)
        puts res
        res['batches'][0]['response'][0].should eq({'id'=>['0013000000ymMBhAAM'], 'success'=>['true'], 'created'=>['false']})
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
          res = @api.update('Account', [{:Id => '0013000000ymMBh', :Website => 'www.test.com'}, {:Id => '0013000000ymMBh', :Website => 'www.test.com'}, {:Id => '0013000000ymMBh', :Website => 'www.test.com'}, {:Id => 'abc123', :Website => 'www.test.com'}], true, 2)
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