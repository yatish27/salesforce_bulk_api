require 'rubygems'
require 'bundler'
require 'net/https'
require 'xmlsimple'
require 'csv'

require 'salesforce_bulk_api/version'
require 'salesforce_bulk_api/concerns/throttling'
require 'salesforce_bulk_api/job'
require 'salesforce_bulk_api/connection'

module SalesforceBulkApi
  class Api
    attr_reader :connection

    SALESFORCE_API_VERSION = '32.0'

    def initialize(client)
      @connection = SalesforceBulkApi::Connection.new(SALESFORCE_API_VERSION, client)
      @listeners = { job_created: [] }
    end

    def upsert(sobject, records, external_field, get_response = false, send_nulls = false, no_null_list = [], batch_size = 10000, timeout = 1500)
      do_operation('upsert', sobject, records, external_field, get_response, timeout, batch_size, send_nulls, no_null_list)
    end

    def update(sobject, records, get_response = false, send_nulls = false, no_null_list = [], batch_size = 10000, timeout = 1500)
      do_operation('update', sobject, records, nil, get_response, timeout, batch_size, send_nulls, no_null_list)
    end

    def create(sobject, records, get_response = false, send_nulls = false, batch_size = 10000, timeout = 1500)
      do_operation('insert', sobject, records, nil, get_response, timeout, batch_size, send_nulls)
    end

    def delete(sobject, records, get_response = false, batch_size = 10000, timeout = 1500)
      do_operation('delete', sobject, records, nil, get_response, timeout, batch_size)
    end

    def query(sobject, query, batch_size = 10000, timeout = 1500)
      do_operation('query', sobject, query, nil, true, timeout, batch_size)
    end

    def counters
      {
        http_get: @connection.counters[:get],
        http_post: @connection.counters[:post],
        upsert: get_counters[:upsert],
        update: get_counters[:update],
        create: get_counters[:create],
        delete: get_counters[:delete],
        query: get_counters[:query]
      }
    end

    # Allows you to attach a listener that accepts the created job (which has a useful #job_id field).  This is useful
    # for recording a job ID persistently before you begin batch work (i.e. start modifying the salesforce database),
    # so if the load process you are writing needs to recover, it can be aware of previous jobs it started and wait
    # for them to finish.
    #
    def on_job_created(&block)
      @listeners[:job_created] << block
    end

    def job_from_id(job_id)
      SalesforceBulkApi::Job.new(job_id: job_id, connection: @connection)
    end

    def do_operation(operation, sobject, records, external_field, get_response, timeout, batch_size, send_nulls = false, no_null_list = [])
      count operation.to_sym

      job = SalesforceBulkApi::Job.new(
        operation: operation,
        sobject: sobject,
        records: records,
        external_field: external_field,
        connection: @connection
      )

      job.create_job(batch_size, send_nulls, no_null_list)
      @listeners[:job_created].each {|callback| callback.call(job)}
      operation == "query" ? job.add_query() : job.add_batches()
      response = job.close_job
      response.merge!({'batches' => job.get_job_result(get_response, timeout)}) if get_response == true
      response
    end

    private

    def get_counters
      @counters ||= Hash.new(0)
    end

    def count(name)
      get_counters[name] += 1
    end

  end
end
