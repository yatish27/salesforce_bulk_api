# Salesforce-Bulk-Api
[![Gem Version](https://badge.fury.io/rb/salesforce_bulk_api.png)](http://badge.fury.io/rb/salesforce_bulk_api)
## Overview

Salesforce bulk API is a simple ruby gem for connecting to and using the Salesforce Bulk API. It is actually a re-written code from [salesforce_bulk](https://github.com/jorgevaldivia/salesforce_bulk).Written to suit many more other features as well.

## How to use

Using this gem is simple and straight forward.

To initialize:

   `sudo gem install salesforce_bulk_api`

or add

   `gem salesforce_bulk_api`
   
in your Gemfile

There are two ways to authenticate with SalesForce to use the Bulk API: databasedotcom & restforce.
Please check out the entire documentation of the gem you decide to use to learn the various ways of authentication.

[Databasedotcom](https://github.com/heroku/databasedotcom)
[Restforce](https://github.com/ejholmes/restforce)


You can use username password combo, OmniAuth, Oauth2
You can use as many records possible in the Array. Governor limits are taken care of inside the gem.


	require 'salesforce_bulk_api'
	client = Databasedotcom::Client.new :client_id =>  SFDC_APP_CONFIG["client_id"], :client_secret => SFDC_APP_CONFIG["client_secret"] #client_id and client_secret respectively
	client.authenticate :token => "my-oauth-token", :instance_url => "http://na1.salesforce.com"  #=> "my-oauth-token"

    salesforce = SalesforceBulkApi::Api.new(client)

OR

	require 'salesforce_bulk_api'
	client = Restforce.new(
	  username:       SFDC_APP_CONFIG['SFDC_USERNAME'],
	  password:       SFDC_APP_CONFIG['SFDC_PASSWORD'],
	  security_token: SFDC_APP_CONFIG['SFDC_SECURITY_TOKEN'],
	  client_id:      SFDC_APP_CONFIG['SFDC_CLIENT_ID'],
	  client_secret:  SFDC_APP_CONFIG['SFDC_CLIENT_SECRET'].to_i,
	  host:           SFDC_APP_CONFIG['SFDC_HOST'],
	  api_version:	  SFDC_APP_CONFIG['API_VERSION']
	)

	salesforce = SalesforceBulkApi::Api.new(client)


### Sample operations:

All operations take an optional hash as their last parameter that sets bulk API job info. The available options are

|Option|Default Param|
|------|-------------|
|:concurrency|Parallel|
|:get\_response|false (true for queries)|
|:timeout|1500|
|:batch\_size|10000 (often needs to be tuned)|
|:send\_nulls|false|
|:no\_null\_list|[]|

# Insert/Create

Add as many fields per record as needed.

	new_account = Hash["name" => "Test Account", "type" => "Other"] 
	records_to_insert = Array.new
	records_to_insert.push(new_account) 

You can add as many records as you want here, just keep in mind that Salesforce has governor limits.

	options = {:concurrency => 'Serial'}
	result = salesforce.create("Account", records_to_insert, options)
	puts "result is: #{result.inspect}"

# Update

	updated_account = Hash["name" => "Test Account -- Updated", id => "a00A0001009zA2m"] # Nearly identical to an insert, but we need to pass the salesforce id.
	records_to_update = Array.new
	records_to_update.push(updated_account)
	salesforce.update("Account", records_to_update)

# Upsert

	upserted_account = Hash["name" => "Test Account -- Upserted", "External_Field_Name" => "123456"] # Fields to be updated. External field must be included
	records_to_upsert = Array.new
	records_to_upsert.push(upserted_account)
	options = {:batch_size => 500}
	salesforce.upsert("Account", records_to_upsert, "External_Field_Name", options) # Note that upsert accepts an extra parameter for the external field name

# Delete

	deleted_account = Hash["id" => "a00A0001009zA2m"] # We only specify the id of the records to delete
	records_to_delete = Array.new
	records_to_delete.push(deleted_account)
	salesforce.delete("Account", records_to_delete)

# Query

	res = salesforce.query("Account", "select id, name, createddate from Account limit 3") # We just need to pass the sobject name and the query string

### Helpful methods:

# Check status of a job via #job_from_id

	job = salesforce.job_from_id('a00A0001009zA2m') # Returns a SalesforceBulkApi::Job instance
	puts "status is: #{job.check_job_status.inspect}"

### Listening to events:

    # A job is created
    # Useful when you need to store the job_id before any work begins, then if you fail during a complex load scenario, you can wait for your
    # previous job(s) to finish.
    salesforce.on_job_created do |job|
      puts "Job #{job.job_id} created!"
    end

### Throttling API calls:

By default, this gem (and maybe your app driving it) will query job/batch statuses at an unbounded rate.  We can fix that, e.g.:

    salesforce.connection.set_status_throttle(30) # only check status of individual jobs/batches every 30 seconds

## Installation

    sudo gem install salesforce_bulk_api
	
## Contribute

Feel to fork and send Pull request
