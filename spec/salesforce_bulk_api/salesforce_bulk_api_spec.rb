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
      host: sfdc_auth_hash['host'])
    @sf_client.authenticate!

    @account_id = auth_hash['salesforce']['test_account_id']

    @api = SalesforceBulkApi::Api.new(@sf_client)
  end

  after :each do

  end

  def clear_test_accounts(api)
    res = api.query('Account', "SELECT id, Name From Account WHERE Name LIKE 'SalesforceBulkApi Test Account%'")
    api.delete('Account', Array(res['batches'][0]['response']).map {|el| {'Id' => el['Id'].first } })
  end

  describe 'upsert' do

    context 'when not passed get_result' do
      it "doesn't return the batches array" do
        res = @api.upsert('Account', [{:Id => @account_id, :Website => 'www.test.com'}], 'Id')
        res['batches'].should be_nil
      end
    end

    context 'when passed get_result = true' do
      it 'returns the batches array' do
        res = @api.upsert('Account', [{:Id => @account_id, :Website => 'www.test.com'}], 'Id', true)
        res['batches'][0]['response'].is_a? Array

        res['batches'][0]['response'][0]['id'][0].should start_with(@account_id)
        res['batches'][0]['response'][0]['success'].should eq ['true']
        res['batches'][0]['response'][0]['created'].should eq ['false']

      end
    end

    context 'when passed send_nulls = true' do
      it 'sets the nil and empty attributes to NULL' do
        @api.update('Account', [{:Id => @account_id, :Website => 'abc123', :Phone => '5678'}], true)
        res = @api.query('Account', "SELECT Website, Phone From Account WHERE Id = '#{@account_id}'")
        res['batches'][0]['response'][0]['Website'][0].should eq 'abc123'
        res['batches'][0]['response'][0]['Phone'][0].should eq '5678'
        res = @api.upsert('Account', [{:Id => @account_id, :Website => '', :Phone => nil}], 'Id', true, true)
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
        @api.update('Account', [{:Id => @account_id, :Website => 'abc123', :Phone => '5678'}], true)
        res = @api.query('Account', "SELECT Website, Phone From Account WHERE Id = '#{@account_id}'")
        res['batches'][0]['response'][0]['Website'][0].should eq 'abc123'
        res['batches'][0]['response'][0]['Phone'][0].should eq '5678'
        res = @api.upsert('Account', [{:Id => @account_id, :Website => '', :Phone => nil}], 'Id', true, true, [:Website, :Phone])
        res['batches'][0]['response'][0]['id'][0].should start_with(@account_id)
        res['batches'][0]['response'][0]['success'].should eq ['true']
        res['batches'][0]['response'][0]['created'].should eq ['false']
        res = @api.query('Account', "SELECT Website, Phone From Account WHERE Id = '#{@account_id}'")
        res['batches'][0]['response'][0]['Website'][0].should eq('abc123')
        res['batches'][0]['response'][0]['Phone'][0].should eq('5678')
      end
    end

  end

  describe "api options" do
    [
      {
        field: 'concurrencyMode', option: :concurrency_mode,  values: ["Parallel", "Serial", nil], default: 'Parallel'
      },
    ].each do |cases|
      cases[:values].each do |value|
        context "when passing #{cases[:option]} = #{value.inspect}" do
          it "sets the #{cases[:field]} to '#{value || cases[:default]}'" do
            api = SalesforceBulkApi::Api.new(@sf_client, '57.0', { cases[:option] => value })
            res = api.create('Account', [{:name => 'SalesforceBulkApi Test Account'}], true)
            update_response = api.update('Account', [{:Id => res['batches'][0]['response'][0]['id'][0], :Website => 'www.test.com'}], true)
            delete_response = clear_test_accounts(api)
            if value
              res[cases[:field]].should eq [value]
              delete_response[cases[:field]].should eq [value]
              update_response[cases[:field]].should eq [value]
            else
              res[cases[:field]].should eq [cases[:default]]
              delete_response[cases[:field]].should eq [cases[:default]]
              update_response[cases[:field]].should eq [cases[:default]]
            end
          end
        end
      end
    end
  end

  describe 'update' do
    context 'when there is not an error' do
      context 'when not passed get_result' do
        it "doesnt return the batches array" do
          res = @api.update('Account', [{:Id => @account_id, :Website => 'www.test.com'}])
          res['batches'].should be_nil
        end
      end

      context 'when passed get_result = true' do
        it 'returns the batches array' do
          res = @api.update('Account', [{:Id => @account_id, :Website => 'www.test.com'}], true)
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

      context 'when passed get_result = true with batches' do
        it 'returns the results array' do
          res = @api.update('Account', [{:Id => @account_id, :Website => 'www.test.com'}, {:Id => @account_id, :Website => 'www.test.com'}, {:Id => @account_id, :Website => 'www.test.com'}, {:Id => 'abc123', :Website => 'www.test.com'}], true, false, [], 2)

          res['batches'][0]['response'][0]['id'][0].should start_with(@account_id)
          res['batches'][0]['response'][0]['success'].should eq ['true']
          res['batches'][0]['response'][0]['created'].should eq ['false']
          res['batches'][0]['response'][1]['id'][0].should start_with(@account_id)
          res['batches'][0]['response'][1]['success'].should eq ['true']
          res['batches'][0]['response'][1]['created'].should eq ['false']

          res['batches'][1]['response'][0]['id'][0].should start_with(@account_id)
          res['batches'][1]['response'][0]['success'].should eq ['true']
          res['batches'][1]['response'][0]['created'].should eq ['false']
          res['batches'][1]['response'][1].should eq({"errors"=>[{"fields"=>["Id"], "message"=>["Account ID: id value of incorrect type: abc123"], "statusCode"=>["MALFORMED_ID"]}], "success"=>["false"], "created"=>["false"]})
        end
      end
    end

  end

  describe 'create' do
    after :each do
      clear_test_accounts(@api)
    end

    context 'when not passed get_result' do
      it "doesn't return the batches array" do
        res = @api.create('Account', [{:name => 'SalesforceBulkApi Test Account'}])
        res['concurrencyMode'].should eq ['Parallel']
        res['batches'].should be_nil
      end
    end

    context 'when passed get_result = true' do
      it 'returns the batches array' do
        res = @api.create('Account', [{:name => 'SalesforceBulkApi Test Account'}], true)
        res['batches'][0]['response'].is_a? Array
        res['batches'][0]['response'][0]['id'][0].should_not be_nil
        res['batches'][0]['response'][0]['success'].should eq ['true']
        res['batches'][0]['response'][0]['created'].should eq ['true']
      end
    end
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
        @api.counters[:http_get].should eq 0
        @api.counters[:query].should eq 0
        @api.query('Account', "SELECT Website, Phone From Account WHERE Id = '#{@account_id}'")
        @api.counters[:http_get].should eq 1
        @api.counters[:query].should eq 1
      end
    end

    context 'when update operations are called' do
      it 'increments operation count and http POST count' do
        @api.counters[:http_post].should eq 0
        @api.counters[:update].should eq 0
        @api.update('Account', [{:Id => @account_id, :Website => 'abc123', :Phone => '5678'}], true)
        @api.counters[:http_post].should eq 1
        @api.counters[:update].should eq 1
      end
    end
  end

end
