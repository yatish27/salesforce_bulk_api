require "rubygems"
require "bundler"
require "net/https"
require "xmlsimple"
require "csv"

require "salesforce_bulk_api/version"
require "salesforce_bulk_api/concerns/throttling"
require "salesforce_bulk_api/job"
require "salesforce_bulk_api/connection"

module SalesforceBulkApi
  class Api
    attr_reader :connection

    def initialize(client, salesforce_api_version = "46.0")
      @connection = SalesforceBulkApi::Connection.new(salesforce_api_version, client)
      @listeners = {job_created: []}
      @counters = Hash.new(0)
    end

    %w[upsert update create delete].each do |operation|
      define_method(operation) do |sobject, records, external_field = nil, **options|
        do_operation(operation, sobject, records, external_field, **options)
      end
    end

    def query(sobject, query, **)
      do_operation("query", sobject, query, nil, get_response: true, **)
    end

    def counters
      {
        http_get: @connection.counters[:get],
        http_post: @connection.counters[:post],
        upsert: @counters[:upsert],
        update: @counters[:update],
        create: @counters[:create],
        delete: @counters[:delete],
        query: @counters[:query]
      }
    end

    # Allows you to attach a listener that accepts the created job (which has a useful #job_id field).
    # This is useful for recording a job ID persistently before you begin batch work (i.e. start modifying the salesforce database),
    # so if the load process you are writing needs to recover, it can be aware of previous jobs it started and wait
    # for them to finish.
    #
    def on_job_created(&block)
      @listeners[:job_created] << block
    end

    def job_from_id(job_id)
      SalesforceBulkApi::Job.new(job_id: job_id, connection: @connection)
    end

    private

    def do_operation(operation, sobject, records, external_field, **options)
      count(operation.to_sym)

      job = SalesforceBulkApi::Job.new(
        operation: operation,
        sobject: sobject,
        records: records,
        external_field: external_field,
        connection: @connection
      )

      job.create_job(options[:batch_size], options[:send_nulls], options[:no_null_list])
      @listeners[:job_created].each { |callback| callback.call(job) }

      (operation == "query") ? job.add_query : job.add_batches

      response = job.close_job
      response.merge!("batches" => job.get_job_result(options[:get_response], options[:timeout])) if options[:get_response]
      response
    end

    def count(name)
      @counters[name] += 1
    end
  end
end
