require 'rubygems'
require 'bundler'
Bundler.require()
require "salesforce_bulk_api/version"
require 'net/https'
require 'xmlsimple'
require 'csv'
require 'salesforce_bulk_api/job'
require 'salesforce_bulk_api/connection'

module SalesforceBulkApi
  
  class Api

    @@SALESFORCE_API_VERSION = '23.0'

    def initialize(client)
      @connection = SalesforceBulkApi::Connection.new(@@SALESFORCE_API_VERSION,client)
    end

    def upsert(sobject, records, external_field, get_response = false)
      self.do_operation('upsert', sobject, records, external_field, get_response)
    end

    def update(sobject, records, get_response = false)
      self.do_operation('update', sobject, records, nil, get_response)
    end

    def create(sobject, records, get_response = false)
      self.do_operation('insert', sobject, records, nil, get_response)
    end

    def delete(sobject, records, get_response = false)
      self.do_operation('delete', sobject, records, nil, get_response)
    end

    def query(sobject, query)
      self.do_operation('query', sobject, query, nil)
    end

    #private

    def do_operation(operation, sobject, records, external_field, get_response = false, timeout = 1500)
      job = SalesforceBulkApi::Job.new(operation, sobject, records, external_field, @connection)

      # TODO: put this in one function
      job_id = job.create_job()
      batch_id = operation == "query" ? job.add_query() : job.add_batches()
      response = job.close_job

      if operation == 'query' or get_response == true
        response = job.get_job_result(get_response, timeout)
      end
      response
    end
  end  # End class
end
