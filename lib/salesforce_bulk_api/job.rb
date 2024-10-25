require "timeout"

module SalesforceBulkApi
  class Job
    attr_reader :job_id

    class SalesforceException < StandardError; end

    XML_HEADER = '<?xml version="1.0" encoding="utf-8" ?>'.freeze

    def initialize(args)
      @job_id = args[:job_id]
      @operation = args[:operation]
      @sobject = args[:sobject]
      @external_field = args[:external_field]
      @records = args[:records]
      @connection = args[:connection]
      @batch_ids = []
    end

    def create_job(batch_size, send_nulls, no_null_list)
      @batch_size = batch_size
      @send_nulls = send_nulls
      @no_null_list = no_null_list

      xml = build_job_xml
      response = post_xml("job", xml)
      parse_job_response(response)
    end

    def close_job
      xml = build_close_job_xml
      response = post_xml("job/#{@job_id}", xml)
      XmlSimple.xml_in(response)
    end

    def add_query
      response = post_xml("job/#{@job_id}/batch/", @records)
      response_parsed = XmlSimple.xml_in(response)
      @batch_ids << response_parsed["id"][0]
    end

    def add_batches
      raise ArgumentError, "Records must be an array of hashes." unless @records.is_a?(Array)

      keys = @records.each_with_object({}) { |pairs, h| pairs.each { |k, v| (h[k] ||= []) << v } }.keys
      batches = @records.each_slice(@batch_size).to_a

      batches.each do |batch|
        @batch_ids << add_batch(keys, batch)
      end
    end

    def get_job_result(return_result, timeout)
      state = []
      Timeout.timeout(timeout, JobTimeout) do
        loop do
          job_status = check_job_status
          break unless job_closed_and_batches_completed?(job_status, state)
          break if @batch_ids.empty?
        end
      end
    rescue JobTimeout => e
      handle_timeout(e)
    ensure
      process_batch_results(state) if return_result
      state
    end

    private

    def build_job_xml
      xml = "#{XML_HEADER}<jobInfo xmlns=\"http://www.force.com/2009/06/asyncapi/dataload\">"
      xml << "<operation>#{@operation}</operation>"
      xml << "<object>#{@sobject}</object>"
      xml << "<externalIdFieldName>#{@external_field}</externalIdFieldName>" if @external_field
      xml << "<contentType>XML</contentType>"
      xml << "</jobInfo>"
    end

    def build_close_job_xml
      "#{XML_HEADER}<jobInfo xmlns=\"http://www.force.com/2009/06/asyncapi/dataload\"><state>Closed</state></jobInfo>"
    end

    def post_xml(path, xml)
      headers = {"Content-Type" => "application/xml; charset=utf-8"}
      @connection.post_xml(nil, path, xml, headers)
    end

    def parse_job_response(response)
      response_parsed = XmlSimple.xml_in(response)
      if response_parsed["exceptionCode"]
        raise SalesforceException, "#{response_parsed["exceptionMessage"][0]} (#{response_parsed["exceptionCode"][0]})"
      end
      @job_id = response_parsed["id"][0]
    end

    def add_batch(keys, batch)
      xml = "#{XML_HEADER}<sObjects xmlns=\"http://www.force.com/2009/06/asyncapi/dataload\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">"
      batch.each { |r| xml << create_sobject(keys, r) }
      xml << "</sObjects>"

      response = post_xml("job/#{@job_id}/batch/", xml)
      response_parsed = XmlSimple.xml_in(response)
      response_parsed["id"]&.first
    end

    def job_closed_and_batches_completed?(job_status, state)
      return false unless job_status && job_status["state"] && job_status["state"][0] == "Closed"

      batch_statuses = {}
      batches_ready = @batch_ids.all? do |batch_id|
        batch_state = batch_statuses[batch_id] = check_batch_status(batch_id)
        batch_state && batch_state["state"] && batch_state["state"][0] && !["Queued", "InProgress"].include?(batch_state["state"][0])
      end

      if batches_ready
        @batch_ids.each do |batch_id|
          state.unshift(batch_statuses[batch_id])
          @batch_ids.delete(batch_id)
        end
      end

      true
    end

    def handle_timeout(error)
      puts "Timeout waiting for Salesforce to process job batches #{@batch_ids} of job #{@job_id}."
      puts error
      raise
    end

    def process_batch_results(state)
      state.each_with_index do |batch_state, i|
        if batch_state["state"][0] == "Completed"
          state[i].merge!("response" => get_batch_result(batch_state["id"][0]))
        end
      end
    end
  end

  class JobTimeout < StandardError; end
end
