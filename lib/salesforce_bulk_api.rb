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

    def upsert(sobject, records, external_field, get_response = false, send_nulls = false, batch_size = 10000, timeout = 1500)
      self.do_operation('upsert', sobject, records, external_field, get_response, timeout, batch_size, send_nulls)
    end

    def update(sobject, records, get_response = false, send_nulls = false, batch_size = 10000, timeout = 1500)
      self.do_operation('update', sobject, records, nil, get_response, timeout, batch_size, send_nulls)
    end

    def create(sobject, records, get_response = false, send_nulls = false, batch_size = 10000, timeout = 1500)
      self.do_operation('insert', sobject, records, nil, get_response, timeout, batch_size, send_nulls)
    end

    def delete(sobject, records, get_response = false, batch_size = 10000, timeout = 1500)
      self.do_operation('delete', sobject, records, nil, get_response, timeout, batch_size)
    end

    def query(sobject, query, batch_size = 10000, timeout = 1500)
      self.do_operation('query', sobject, query, nil, true, timeout, batch_size)
    end

    #private

    def do_operation(operation, sobject, records, external_field, get_response, timeout, batch_size, send_nulls = false)
      job = SalesforceBulkApi::Job.new(operation, sobject, records, external_field, @connection)

      job_id = job.create_job()
      operation == "query" ? job.add_query() : job.add_batches(batch_size, send_nulls)
      response = job.close_job
      response.merge!({'batches' => job.get_job_result(get_response, timeout)}) if get_response == true
      response
    end
  end  # End class
end
