module SalesforceBulkApi

  class Job

    def initialize(operation, sobject, records, external_field, connection)

      @operation = operation
      @sobject = sobject
      @external_field = external_field
      @records = records
      @connection = connection
      @batch_ids = []
      @XML_HEADER = '<?xml version="1.0" encoding="utf-8" ?>'

    end

    def create_job()
      xml = "#{@XML_HEADER}<jobInfo xmlns=\"http://www.force.com/2009/06/asyncapi/dataload\">"
      xml += "<operation>#{@operation}</operation>"
      xml += "<object>#{@sobject}</object>"
      if !@external_field.nil? # This only happens on upsert
        xml += "<externalIdFieldName>#{@external_field}</externalIdFieldName>"
      end
      xml += "<contentType>XML</contentType>"
      xml += "</jobInfo>"

      path = "job"
      headers = Hash['Content-Type' => 'application/xml; charset=utf-8']

      response = @connection.post_xml(nil, path, xml, headers)
      response_parsed = XmlSimple.xml_in(response)
      @job_id = response_parsed['id'][0]
    end

    def close_job()
      xml = "#{@XML_HEADER}<jobInfo xmlns=\"http://www.force.com/2009/06/asyncapi/dataload\">"
      xml += "<state>Closed</state>"
      xml += "</jobInfo>"

      path = "job/#{@job_id}"
      headers = Hash['Content-Type' => 'application/xml; charset=utf-8']

      response = @connection.post_xml(nil, path, xml, headers)
      response_parsed = XmlSimple.xml_in(response)

      #job_id = response_parsed['id'][0]
    end

    def add_query
      path = "job/#{@job_id}/batch/"
      headers = Hash["Content-Type" => "application/xml; charset=UTF-8"]

      response = @connection.post_xml(nil, path, @records, headers)
      response_parsed = XmlSimple.xml_in(response)

      @batch_ids << response_parsed['id'][0]
    end

    def add_batches(batch_size, send_nulls)
      raise 'Records must be an array of hashes.' unless @records.is_a? Array
      keys = @records.reduce({}) {|h,pairs| pairs.each {|k,v| (h[k] ||= []) << v}; h}.keys
      headers = keys
      @records_dup = @records.clone
      super_records = []
      (@records_dup.size/batch_size).to_i.times do
        super_records << @records_dup.pop(batch_size)
      end
      super_records << @records_dup unless @records_dup.empty?

      super_records.each do |batch|
        @batch_ids << add_batch(keys, batch, send_nulls)
      end
    end
    
    def add_batch(keys, batch, send_nulls)
      xml = "#{@XML_HEADER}<sObjects xmlns=\"http://www.force.com/2009/06/asyncapi/dataload\">"
      batch.each do |r|
        xml += create_sobject(keys, r, send_nulls)
      end
      xml += "</sObjects>"
      path = "job/#{@job_id}/batch/"
      headers = Hash["Content-Type" => "application/xml; charset=UTF-8"]
      response = @connection.post_xml(nil, path, xml, headers)
      response_parsed = XmlSimple.xml_in(response)
      response_parsed['id'][0] if response_parsed['id']
    end
    
    def create_sobject(keys, r, send_nulls)
      sobject_xml = ''
      object_keys = ''
      fields_to_null = []
      keys.each do |k|
        object_keys += "<#{k}>"
        unless r[k].to_s.empty?
          if r[k].respond_to?(:encode)
            object_keys += r[k].encode(:xml => :text)
          end
        end
        object_keys += "</#{k}>"
        if r[k].to_s.empty? && send_nulls
          fields_to_null << k
        end
      end
      sobject_xml += "<sObject "
      if send_nulls
        sobject_xml += "fieldsToNull=\"["
        sobject_xml += fields_to_null.inject('') {|memo, field| memo << "'#{field}',"}
        sobject_xml.slice!(sobject_xml.length - 1)
        sobject_xml += "]\""
      end
      sobject_xml += ">"
      sobject_xml += object_keys
      sobject_xml += "</sObject>"
      sobject_xml
    end
    
    def check_job_status
      path = "job/#{@job_id}"
      headers = Hash.new

      response = @connection.get_request(nil, path, headers)

      begin
        response_parsed = XmlSimple.xml_in(response) if response
        response_parsed
      rescue StandardError => e
        nil
      end
    end
    
    def check_batch_status(batch_id)
      path = "job/#{@job_id}/batch/#{batch_id}"
      headers = Hash.new

      response = @connection.get_request(nil, path, headers)

      begin
        response_parsed = XmlSimple.xml_in(response) if response
        response_parsed
      rescue StandardError => e
        nil
      end
    end
    
    def get_job_result(return_result, timeout)
      # timeout is in seconds
      state = []
      Timeout::timeout(timeout, SalesforceBulkApi::JobTimeout) do
        while true
          if self.check_job_status['state'][0] == 'Closed'
            @batch_ids.each do |batch_id|
              batch_state = self.check_batch_status(batch_id)
              if batch_state['state'][0] != "Queued" && batch_state['state'][0] != "InProgress"
                state << (batch_state)
                @batch_ids.delete(batch_id)
              end
              sleep(2) # wait x seconds and check again
            end
            break if @batch_ids.empty?
          else
            break
          end
        end
      end
      
      state.each_with_index do |batch_state, i|
        if batch_state['state'][0] == 'Completed' && return_result == true
          state[i].merge!({'response' => self.get_batch_result(batch_state['id'][0])})
        end
      end
      state
    end

    def get_batch_result(batch_id)
      path = "job/#{@job_id}/batch/#{batch_id}/result"
      headers = Hash["Content-Type" => "application/xml; charset=UTF-8"]

      response = @connection.get_request(nil, path, headers)
      response_parsed = XmlSimple.xml_in(response)
      results = response_parsed['result'] unless @operation == 'query'

      if(@operation == 'query') # The query op requires us to do another request to get the results
        result_id = response_parsed["result"][0]
        path = "job/#{@job_id}/batch/#{batch_id}/result/#{result_id}"
        headers = Hash.new
        headers = Hash["Content-Type" => "application/xml; charset=UTF-8"]
        response = @connection.get_request(nil, path, headers)
        response_parsed = XmlSimple.xml_in(response)
        results = response_parsed['records']
      end
      results
    end
    
  end
  
  class JobTimeout < StandardError  
  end
end
