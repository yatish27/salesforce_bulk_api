require "spec_helper"
require "yaml"
require "restforce"

describe SalesforceBulkApi do
  before :each do
    @sf_client = Restforce.new(
      username: ENV["SALESFORCE_USERNAME"],
      password: ENV["SALESFORCE_PASSWORD"],
      client_id: ENV["SALESFORCE_CLIENT_ID"],
      client_secret: ENV["SALESFORCE_CLIENT_SECRET"],
      host: ENV["SALESFORCE_HOST"],
      security_token: ENV["SALESFORCE_SECURITY_TOKEN"]
    )

    @sf_client.authenticate!

    @account_id = ENV["SALESFORCE_TEST_ACCOUNT_ID"]

    @api = SalesforceBulkApi::Api.new(@sf_client)
  end

  describe "upsert" do
    context "when not passed get_result" do
      it "doesn't return the batches array" do
        res = @api.upsert("Account", [{Id: @account_id, Website: "www.test.com"}], "Id")
        res["batches"].should be_nil
      end
    end

    context "when passed get_result = true" do
      it "returns the batches array" do
        res = @api.upsert("Account", [{Id: @account_id, Website: "www.test.com"}], "Id", true)
        res["batches"][0]["response"].is_a? Array

        res["batches"][0]["response"][0]["id"][0].should start_with(@account_id)
        res["batches"][0]["response"][0]["success"].should eq ["true"]
        res["batches"][0]["response"][0]["created"].should eq ["false"]
      end
    end

    context "when passed send_nulls = true" do
      it "sets the nil and empty attributes to NULL" do
        @api.update("Account", [{Id: @account_id, Website: "abc123", Phone: "5678"}], true)
        res = @api.query("Account", "SELECT Website, Phone From Account WHERE Id = '#{@account_id}'")
        res["batches"][0]["response"][0]["Website"][0].should eq "abc123"
        res["batches"][0]["response"][0]["Phone"][0].should eq "5678"
        res = @api.upsert("Account", [{Id: @account_id, Website: "", Phone: nil}], "Id", true, true)
        res["batches"][0]["response"][0]["id"][0].should start_with(@account_id)
        res["batches"][0]["response"][0]["success"].should eq ["true"]
        res["batches"][0]["response"][0]["created"].should eq ["false"]
        res = @api.query("Account", "SELECT Website, Phone From Account WHERE Id = '#{@account_id}'")
        res["batches"][0]["response"][0]["Website"][0].should eq({"xsi:nil" => "true"})
        res["batches"][0]["response"][0]["Phone"][0].should eq({"xsi:nil" => "true"})
      end
    end

    context "when passed send_nulls = true and an array of fields not to null" do
      it "sets the nil and empty attributes to NULL, except for those included in the list of fields to ignore" do
        @api.update("Account", [{Id: @account_id, Website: "abc123", Phone: "5678"}], true)
        res = @api.query("Account", "SELECT Website, Phone From Account WHERE Id = '#{@account_id}'")
        res["batches"][0]["response"][0]["Website"][0].should eq "abc123"
        res["batches"][0]["response"][0]["Phone"][0].should eq "5678"
        res = @api.upsert("Account", [{Id: @account_id, Website: "", Phone: nil}], "Id", true, true, [:Website, :Phone])
        res["batches"][0]["response"][0]["id"][0].should start_with(@account_id)
        res["batches"][0]["response"][0]["success"].should eq ["true"]
        res["batches"][0]["response"][0]["created"].should eq ["false"]
        res = @api.query("Account", "SELECT Website, Phone From Account WHERE Id = '#{@account_id}'")
        res["batches"][0]["response"][0]["Website"][0].should eq("abc123")
        res["batches"][0]["response"][0]["Phone"][0].should eq("5678")
      end
    end
  end

  describe "update" do
    context "when there is not an error" do
      context "when not passed get_result" do
        it "doesnt return the batches array" do
          res = @api.update("Account", [{Id: @account_id, Website: "www.test.com"}])
          res["batches"].should be_nil
        end
      end

      context "when passed get_result = true" do
        it "returns the batches array" do
          res = @api.update("Account", [{Id: @account_id, Website: "www.test.com"}], true)
          res["batches"][0]["response"].is_a? Array
          res["batches"][0]["response"][0]["id"][0].should start_with(@account_id)
          res["batches"][0]["response"][0]["success"].should eq ["true"]
          res["batches"][0]["response"][0]["created"].should eq ["false"]
        end
      end
    end

    context "when there is an error" do
      context "when not passed get_result" do
        it "doesn't return the results array" do
          res = @api.update("Account", [{Id: @account_id, Website: "www.test.com"}, {Id: "abc123", Website: "www.test.com"}])
          res["batches"].should be_nil
        end
      end

      context "when passed get_result = true with batches" do
        it "returns the results array" do
          res = @api.update("Account", [{Id: @account_id, Website: "www.test.com"}, {Id: @account_id, Website: "www.test.com"}, {Id: @account_id, Website: "www.test.com"}, {Id: "abc123", Website: "www.test.com"}], true, false, [], 2)

          res["batches"][0]["response"][0]["id"][0].should start_with(@account_id)
          res["batches"][0]["response"][0]["success"].should eq ["true"]
          res["batches"][0]["response"][0]["created"].should eq ["false"]
          res["batches"][0]["response"][1]["id"][0].should start_with(@account_id)
          res["batches"][0]["response"][1]["success"].should eq ["true"]
          res["batches"][0]["response"][1]["created"].should eq ["false"]

          res["batches"][1]["response"][0]["id"][0].should start_with(@account_id)
          res["batches"][1]["response"][0]["success"].should eq ["true"]
          res["batches"][1]["response"][0]["created"].should eq ["false"]
          res["batches"][1]["response"][1].should eq({"errors" => [{"fields" => ["Id"], "message" => ["Account ID: id value of incorrect type: abc123"], "statusCode" => ["MALFORMED_ID"]}], "success" => ["false"], "created" => ["false"]})
        end
      end
    end
  end

  describe "create" do
    pending
  end

  describe "delete" do
    pending
  end

  describe "query" do
    context "when there are results" do
      it "returns the query results" do
        res = @api.query("Account", "SELECT id, Name From Account WHERE Name LIKE 'Test%'")
        res["batches"][0]["response"].length.should > 1
        res["batches"][0]["response"][0]["Id"].should_not be_nil
      end

      context "and there are multiple batches" do
        # need dev to create > 10k records in dev organization
        it "returns the query results in a merged hash"
      end
    end

    context "when there are no results" do
      it "returns nil" do
        res = @api.query("Account", "SELECT id From Account WHERE Name = 'ABC'")
        res["batches"][0]["response"].should eq nil
      end
    end

    context "when there is an error" do
      it "returns nil" do
        res = @api.query("Account", "SELECT id From Account WHERE Name = ''ABC'")
        res["batches"][0]["response"].should eq nil
      end
    end
  end
end
