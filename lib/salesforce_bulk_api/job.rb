module SalesforceBulkApi

  class Job

    def initialize(operation, sobject, records, external_field, connection)

      @operation = operation
      @sobject = sobject
      @external_field = external_field
      @records = records
      @connection = connection
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

      @batch_id = response_parsed['id'][0]
    end

    def add_batch()
      raise 'Records must be an array of hashes.' unless @records.is_a? Array
      keys = @records.reduce({}) {|h,pairs| pairs.each {|k,v| (h[k] ||= []) << v}; h}.keys
      headers = keys
      @records_dup = @records.clone
      super_records = []
      (@records_dup.size/10000).to_i.times do
        super_records << @records_dup.pop(10000)
      end
      super_records << @records_dup

      super_records.each do |batch|
        xml = "#{@XML_HEADER}<sObjects xmlns=\"http://www.force.com/2009/06/asyncapi/dataload\">"
        batch.each do |r|
          xml += "<sObject>"
          keys.each do |k|
            unless r[k].blank?
              if r[k].is_a? String
                xml += "<#{k}>#{r[k].encode(:xml => :text)}</#{k}>"
              else
                xml += "<#{k}>#{r[k]}</#{k}>"
              end
            end
          end
          xml += "</sObject>"
        end
        xml += "</sObjects>"

        path = "job/#{@job_id}/batch/"
        headers = Hash["Content-Type" => "application/xml; charset=UTF-8"]
        response = @connection.post_xml(nil, path, xml, headers)
        response_parsed = XmlSimple.xml_in(response)

        @batch_id = response_parsed['id'][0]
      end
    end

    def check_batch_status()
      path = "job/#{@job_id}/batch/#{@batch_id}"
      headers = Hash.new

      response = @connection.get_request(nil, path, headers)
      response_parsed = XmlSimple.xml_in(response)

      begin
        response_parsed
      rescue Exception => e
        nil
      end
    end

    def get_batch_result()
      path = "job/#{@job_id}/batch/#{@batch_id}/result"
      headers = Hash["Content-Type" => "application/xml; charset=UTF-8"]

      response = @connection.get_request(nil, path, headers)
      response_parsed = XmlSimple.xml_in(response)
      results = response_parsed['result'] unless @operation == 'query'

      if(@operation == 'query') # The query op requires us to do another request to get the results
        result_id = response_parsed["result"][0]
        path = "job/#{@job_id}/batch/#{@batch_id}/result/#{result_id}"
        headers = Hash.new
        headers = Hash["Content-Type" => "application/xml; charset=UTF-8"]
        response = @connection.get_request(nil, path, headers)
        response_parsed = XmlSimple.xml_in(response)
        results = response_parsed['records']
      end
      results
    end

  end
end
