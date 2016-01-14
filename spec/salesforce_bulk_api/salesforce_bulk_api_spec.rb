require 'spec_helper'
require 'yaml'
require 'restforce'

describe SalesforceBulkApi do

  before :each do
    auth_hash = YAML.load_file('auth_credentials.yml')
    sfdc_auth_hash = auth_hash['salesforce']

    @sf_client = Restforce.new(
      username: sfdc_auth_hash['user'],
      password: sfdc_auth_hash['passwordandtoken'],
      client_id: sfdc_auth_hash['client_id'],
      client_secret: sfdc_auth_hash['client_secret'],
      host: sfdc_auth_hash['host'],
      api_version: sfdc_auth_hash.fetch('api_version', '32.0')
    )
    @sf_client.authenticate!

    @account_id = auth_hash['salesforce']['test_account_id']

    @api = SalesforceBulkApi::Api.new(@sf_client)
  end

  after :each do

  end

  describe 'options' do
    context 'process jobs in serial mode when sent serial option in hash' do
      it 'returns serial mode' do
        res = @api.upsert('Account', [{:Id => @account_id, :Website => 'www.test.com'}], 'Id', {:concurrency => 'Serial'})
        res['concurrencyMode'].should eq ["Serial"]
      end
    end
  end

  describe 'client' do
    context 'api version' do
      it 'gets set based on client, not constant' do
        res = @api.query('Account', "SELECT Website, Phone From Account WHERE Id = '#{@account_id}'")
        res['apiVersion'].should eq [@sf_client.options[:api_version]]
      end
    end
  end

  describe 'upsert' do
    context 'when not passed get_result' do
      it "doesn't return the batches array" do
        res = @api.upsert('Account', [{:Id => @account_id, :Website => 'www.test.com'}], 'Id')
        res['batches'].should be_nil
      end
    end

    context 'when passed get_response = true' do
      it 'returns the batches array' do
        res = @api.upsert('Account', [{:Id => @account_id, :Website => 'www.test.com'}], 'Id', {:get_response => true})
        res['batches'][0]['response'].is_a? Array

        res['batches'][0]['response'][0]['id'][0].should start_with(@account_id)
        res['batches'][0]['response'][0]['success'].should eq ['true']
        res['batches'][0]['response'][0]['created'].should eq ['false']

      end
    end

    context 'when passed send_nulls = true' do
      it 'sets the nil and empty attributes to NULL' do
        @api.update('Account', [{:Id => @account_id, :Website => 'abc123', :Phone => '5678'}], {:get_response => true})
        res = @api.query('Account', "SELECT Website, Phone From Account WHERE Id = '#{@account_id}'")
        res['batches'][0]['response'][0]['Website'][0].should eq 'abc123'
        res['batches'][0]['response'][0]['Phone'][0].should eq '5678'
        res = @api.upsert('Account', [{:Id => @account_id, :Website => '', :Phone => nil}], 'Id', {:get_response => true, :send_nulls => true})
        res['batches'][0]['response'][0]['id'][0].should start_with(@account_id)
        res['batches'][0]['response'][0]['success'].should eq ['true']
        res['batches'][0]['response'][0]['created'].should eq ['false']
        res = @api.query('Account', "SELECT Website, Phone From Account WHERE Id = '#{@account_id}'")
        res['batches'][0]['response'][0]['Website'][0].should eq({"xsi:nil" => "true"})
        res['batches'][0]['response'][0]['Phone'][0].should eq({"xsi:nil" => "true"})
      end
    end

    context 'when passed send_nulls = true and an array of fields not to null' do
      it 'sets the nil and empty attributes to NULL, except for those included in the list of fields to ignore' do
        @api.update('Account', [{:Id => @account_id, :Website => 'abc123', :Phone => '5678'}], {:get_response => true})
        res = @api.query('Account', "SELECT Website, Phone From Account WHERE Id = '#{@account_id}'")
        res['batches'][0]['response'][0]['Website'][0].should eq 'abc123'
        res['batches'][0]['response'][0]['Phone'][0].should eq '5678'
        res = @api.upsert('Account', [{:Id => @account_id, :Website => '', :Phone => nil}], 'Id', {:get_response => true, :send_nulls => true, :no_null_list => [:Website, :Phone]})
        res['batches'][0]['response'][0]['id'][0].should start_with(@account_id)
        res['batches'][0]['response'][0]['success'].should eq ['true']
        res['batches'][0]['response'][0]['created'].should eq ['false']
        res = @api.query('Account', "SELECT Website, Phone From Account WHERE Id = '#{@account_id}'")
        res['batches'][0]['response'][0]['Website'][0].should eq('abc123')
        res['batches'][0]['response'][0]['Phone'][0].should eq('5678')
      end
    end

  end

  describe 'update' do
    context 'when there is not an error' do
      context 'when not passed get_response' do
        it "doesnt return the batches array" do
          res = @api.update('Account', [{:Id => @account_id, :Website => 'www.test.com'}])
          res['batches'].should be_nil
        end
      end

      context 'when passed get_response = true' do
        it 'returns the batches array' do
          res = @api.update('Account', [{:Id => @account_id, :Website => 'www.test.com'}], {:get_response => true})
          res['batches'][0]['response'].is_a? Array
          res['batches'][0]['response'][0]['id'][0].should start_with(@account_id)
          res['batches'][0]['response'][0]['success'].should eq ['true']
          res['batches'][0]['response'][0]['created'].should eq ['false']
        end
      end
    end

    context 'when there is an error' do
      context 'when not passed get_result' do
        it "doesn't return the results array" do
          res = @api.update('Account', [{:Id => @account_id, :Website => 'www.test.com'},{:Id => 'abc123', :Website => 'www.test.com'}])
          res['batches'].should be_nil
        end
      end

      context 'when passed get_response = true with batches' do
        it 'returns the results array' do
          res = @api.update('Account', [{:Id => @account_id, :Website => 'www.test.com'}, {:Id => @account_id, :Website => 'www.test.com'}, {:Id => @account_id, :Website => 'www.test.com'}, {:Id => 'abc123', :Website => 'www.test.com'}], {:get_response => true, :batch_size => 2})
          res['batches'][0]['response'][0]['id'][0].should start_with(@account_id)
          res['batches'][0]['response'][0]['success'].should eq ['true']
          res['batches'][0]['response'][0]['created'].should eq ['false']

          res['batches'][0]['response'][1].should eq({"errors"=>[{"fields"=>["Id"], "message"=>["Account ID: id value of incorrect type: abc123"], "statusCode"=>["MALFORMED_ID"]}], "success"=>["false"], "created"=>["false"]})

          res['batches'][1]['response'][0]['id'][0].should start_with(@account_id)
          res['batches'][1]['response'][0]['success'].should eq ['true']
          res['batches'][1]['response'][0]['created'].should eq ['false']
          res['batches'][1]['response'][1]['id'][0].should start_with(@account_id)
          res['batches'][1]['response'][1]['success'].should eq ['true']
          res['batches'][1]['response'][1]['created'].should eq ['false']
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
        # need dev to create > 10k records in dev organization
        it 'returns the query results in a merged hash'
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

  describe 'counters' do
    context 'when read operations are called' do
      it 'increments operation count and http GET count' do
        # queries fire multiple get_requests when checking for results 
        @api.counters[:http_get].should eq 0
        @api.counters[:query].should eq 0
        @api.query('Account', "SELECT Website, Phone From Account WHERE Id = '#{@account_id}'")
        @api.counters[:http_get].should eq 4
        @api.counters[:query].should eq 1
      end
    end

    context 'when update operations are called' do
      it 'increments operation count and http POST count' do
        # updates fire multiple post_xml functions: create_job, add_batch, close_job, and get_job_result
        @api.counters[:http_post].should eq 0
        @api.counters[:update].should eq 0
        @api.update('Account', [{:Id => @account_id, :Website => 'abc123', :Phone => '5678'}], {:get_response => true})
        @api.counters[:http_post].should eq 3 
        @api.counters[:update].should eq 1
      end
    end
  end

end
