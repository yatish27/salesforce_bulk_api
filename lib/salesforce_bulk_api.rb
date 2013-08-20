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

    def upsert(sobject, records, external_field, get_result = false)
      self.do_operation('upsert', sobject, records, external_field, get_result)
    end

    def update(sobject, records, get_result = false)
      self.do_operation('update', sobject, records, nil, get_result)
    end

    def create(sobject, records, get_result = false)
      self.do_operation('insert', sobject, records, nil, get_result)
    end

    def delete(sobject, records, get_result = false)
      self.do_operation('delete', sobject, records, nil, get_result)
    end

    def query(sobject, query)
      self.do_operation('query', sobject, query, nil)
    end

    #private

    def do_operation(operation, sobject, records, external_field, get_result = false)
      job = SalesforceBulkApi::Job.new(operation, sobject, records, external_field, @connection)

      # TODO: put this in one function
      job_id = job.create_job()
      batch_id = operation == "query" ? job.add_query() : job.add_batch()
      job.close_job()

      while true
        state = job.check_batch_status()
        if state['state'][0] != "Queued" && state['state'][0] != "InProgress"
          break
        end
        sleep(2) # wait x seconds and check again
      end

      if state['state'][0] == 'Completed'
        state.merge!({'result' => job.get_batch_result()}) if (operation == 'query' || get_result == true)
        return state
      else
        return state
      end
    end
  end  # End class
end
