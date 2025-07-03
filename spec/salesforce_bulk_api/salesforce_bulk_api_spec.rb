require "spec_helper"
require "yaml"
require "restforce"

describe SalesforceBulkApi do
  let(:sf_client) do
    client = Restforce.new(
      username: ENV["SALESFORCE_USERNAME"],
      password: ENV["SALESFORCE_PASSWORD"],
      client_id: ENV["SALESFORCE_CLIENT_ID"],
      client_secret: ENV["SALESFORCE_CLIENT_SECRET"],
      host: ENV["SALESFORCE_HOST"],
      security_token: ENV["SALESFORCE_SECURITY_TOKEN"]
    )
    client.authenticate!
    client
  end

  let(:account_id) { ENV["SALESFORCE_TEST_ACCOUNT_ID"] }
  let(:api) { SalesforceBulkApi::Api.new(sf_client) }

  describe "upsert" do
    context "when not passed get_result" do
      it "doesn't return the batches array" do
        res = api.upsert("Account", [{Id: account_id, Website: "www.test.com"}], "Id")
        expect(res["batches"]).to be_nil
      end
    end

    context "when passed get_result = true" do
      it "returns the batches array" do
        res = api.upsert("Account", [{Id: account_id, Website: "www.test.com"}], "Id", true)
        expect(res["batches"][0]["response"]).to be_a Array

        expect(res["batches"][0]["response"][0]["id"][0]).to start_with(account_id)
        expect(res["batches"][0]["response"][0]["success"]).to eq ["true"]
        expect(res["batches"][0]["response"][0]["created"]).to eq ["false"]
      end
    end

    context "when passed send_nulls = true" do
      it "sets the nil and empty attributes to NULL" do
        api.update("Account", [{Id: account_id, Website: "abc123", Phone: "5678"}], true)
        res = api.query("Account", "SELECT Website, Phone From Account WHERE Id = '#{account_id}'")
        expect(res["batches"][0]["response"][0]["Website"][0]).to eq "abc123"
        expect(res["batches"][0]["response"][0]["Phone"][0]).to eq "5678"
        res = api.upsert("Account", [{Id: account_id, Website: "", Phone: nil}], "Id", true, true)
        expect(res["batches"][0]["response"][0]["id"][0]).to start_with(account_id)
        expect(res["batches"][0]["response"][0]["success"]).to eq ["true"]
        expect(res["batches"][0]["response"][0]["created"]).to eq ["false"]
        res = api.query("Account", "SELECT Website, Phone From Account WHERE Id = '#{account_id}'")
        expect(res["batches"][0]["response"][0]["Website"][0]).to eq({"xsi:nil" => "true"})
        expect(res["batches"][0]["response"][0]["Phone"][0]).to eq({"xsi:nil" => "true"})
      end
    end

    context "when passed send_nulls = true and an array of fields not to null" do
      it "sets the nil and empty attributes to NULL, except for those included in the list of fields to ignore" do
        api.update("Account", [{Id: account_id, Website: "abc123", Phone: "5678"}], true)
        res = api.query("Account", "SELECT Website, Phone From Account WHERE Id = '#{account_id}'")
        expect(res["batches"][0]["response"][0]["Website"][0]).to eq "abc123"
        expect(res["batches"][0]["response"][0]["Phone"][0]).to eq "5678"
        res = api.upsert("Account", [{Id: account_id, Website: "", Phone: nil}], "Id", true, true, [:Website, :Phone])
        expect(res["batches"][0]["response"][0]["id"][0]).to start_with(account_id)
        expect(res["batches"][0]["response"][0]["success"]).to eq ["true"]
        expect(res["batches"][0]["response"][0]["created"]).to eq ["false"]
        res = api.query("Account", "SELECT Website, Phone From Account WHERE Id = '#{account_id}'")
        expect(res["batches"][0]["response"][0]["Website"][0]).to eq("abc123")
        expect(res["batches"][0]["response"][0]["Phone"][0]).to eq("5678")
      end
    end
  end

  describe "update" do
    context "when there is not an error" do
      context "when not passed get_result" do
        it "doesnt return the batches array" do
          res = api.update("Account", [{Id: account_id, Website: "www.test.com"}])
          expect(res["batches"]).to be_nil
        end
      end

      context "when passed get_result = true" do
        it "returns the batches array" do
          res = api.update("Account", [{Id: account_id, Website: "www.test.com"}], true)
          expect(res["batches"][0]["response"]).to be_a Array
          expect(res["batches"][0]["response"][0]["id"][0]).to start_with(account_id)
          expect(res["batches"][0]["response"][0]["success"]).to eq ["true"]
          expect(res["batches"][0]["response"][0]["created"]).to eq ["false"]
        end
      end
    end

    context "when there is an error" do
      context "when not passed get_result" do
        it "doesn't return the results array" do
          res = api.update("Account", [{Id: account_id, Website: "www.test.com"}, {Id: "abc123", Website: "www.test.com"}])
          expect(res["batches"]).to be_nil
        end
      end

      context "when passed get_result = true with batches" do
        it "returns the results array" do
          res = api.update("Account", [{Id: account_id, Website: "www.test.com"}, {Id: account_id, Website: "www.test.com"}, {Id: account_id, Website: "www.test.com"}, {Id: "abc123", Website: "www.test.com"}], true, false, [], 2)

          expect(res["batches"][0]["response"][0]["id"][0]).to start_with(account_id)
          expect(res["batches"][0]["response"][0]["success"]).to eq ["true"]
          expect(res["batches"][0]["response"][0]["created"]).to eq ["false"]
          expect(res["batches"][0]["response"][1]["id"][0]).to start_with(account_id)
          expect(res["batches"][0]["response"][1]["success"]).to eq ["true"]
          expect(res["batches"][0]["response"][1]["created"]).to eq ["false"]

          expect(res["batches"][1]["response"][0]["id"][0]).to start_with(account_id)
          expect(res["batches"][1]["response"][0]["success"]).to eq ["true"]
          expect(res["batches"][1]["response"][0]["created"]).to eq ["false"]
          expect(res["batches"][1]["response"][1]).to eq({"errors" => [{"fields" => ["Id"], "message" => ["Account ID: id value of incorrect type: abc123"], "statusCode" => ["MALFORMED_ID"]}], "success" => ["false"], "created" => ["false"]})
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
        res = api.query("Account", "SELECT id, Name From Account WHERE Name LIKE 'Test%'")
        expect(res["batches"][0]["response"].length).to be > 1
        expect(res["batches"][0]["response"][0]["Id"]).not_to be_nil
      end

      context "and there are multiple batches" do
        # need dev to create > 10k records in dev organization
        it "returns the query results in a merged hash"
      end
    end

    context "when there are no results" do
      it "returns nil" do
        res = api.query("Account", "SELECT id From Account WHERE Name = 'ABC'")
        expect(res["batches"][0]["response"]).to be_nil
      end
    end

    context "when there is an error" do
      it "returns nil" do
        res = api.query("Account", "SELECT id From Account WHERE Name = ''ABC'")
        expect(res["batches"][0]["response"]).to be_nil
      end
    end
  end
end
