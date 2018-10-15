# Salesforce-Bulk-Api
[![Gem Version](https://badge.fury.io/rb/salesforce_bulk_api.png)](http://badge.fury.io/rb/salesforce_bulk_api)

## Overview

`SalesforceBulkApi` is a ruby wrapper for the Salesforce Bulk API.
It is rewritten from [salesforce_bulk](https://github.com/jorgevaldivia/salesforce_bulk).
It adds some missing features of `salesforce_bulk`.

## How to use

Using this gem is simple and straight forward.

### Install

   `gem install salesforce_bulk_api`

or add it to your Gemfile

   `gem salesforce_bulk_api`

### Authenticate

You can authenticate with Salesforce using two gems, `databasedotcom` & `restforce`.

Please check the documentation of the respective gems to learn how to authenticate with Salesforce

[Databasedotcom](https://github.com/heroku/databasedotcom)
[Restforce](https://github.com/ejholmes/restforce)

You can use username password combo, OmniAuth, Oauth2
You can use as many records possible in the Array. Governor limits are taken care of inside the gem.

```ruby
require 'salesforce_bulk_api'

client = Databasedotcom::Client.new(
  :client_id =>  SFDC_APP_CONFIG["client_id"],
  :client_secret => SFDC_APP_CONFIG["client_secret"]
)
client.authenticate(
  :token => "my-oauth-token",
  :instance_url => "http://na1.salesforce.com"
)

salesforce = SalesforceBulkApi::Api.new(client)
```

OR

```ruby
require 'salesforce_bulk_api'
client = Restforce.new(
  username:       SFDC_APP_CONFIG['SFDC_USERNAME'],
  password:       SFDC_APP_CONFIG['SFDC_PASSWORD'],
  security_token: SFDC_APP_CONFIG['SFDC_SECURITY_TOKEN'],
  client_id:      SFDC_APP_CONFIG['SFDC_CLIENT_ID'],
  client_secret:  SFDC_APP_CONFIG['SFDC_CLIENT_SECRET'].to_i,
  host:           SFDC_APP_CONFIG['SFDC_HOST']
)
client.authenticate!

salesforce = SalesforceBulkApi::Api.new(client)
```

### Sample operations:

```ruby
# Insert/Create
# Add as many fields per record as needed.
new_account = Hash["name" => "Test Account", "type" => "Other"]
records_to_insert = Array.new
# You can add as many records as you want here, just keep in mind that Salesforce has governor limits.
records_to_insert.push(new_account)
result = salesforce.create("Account", records_to_insert)
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
salesforce.upsert("Account", records_to_upsert, "External_Field_Name") # Note that upsert accepts an extra parameter for the external field name

# Delete
deleted_account = Hash["id" => "a00A0001009zA2m"] # We only specify the id of the records to delete
records_to_delete = Array.new
records_to_delete.push(deleted_account)
salesforce.delete("Account", records_to_delete)

# Query
res = salesforce.query("Account", "select id, name, createddate from Account limit 3") # We just need to pass the sobject name and the query string
```

### Helpful methods:

```ruby
# Check status of a job via #job_from_id
job = salesforce.job_from_id('a00A0001009zA2m') # Returns a SalesforceBulkApi::Job instance
puts "status is: #{job.check_job_status.inspect}"
```

### Listening to events:

```ruby
# A job is created
# Useful when you need to store the job_id before any work begins, then if you fail during a complex load scenario, you can wait for your
# previous job(s) to finish.
salesforce.on_job_created do |job|
  puts "Job #{job.job_id} created!"
end
```

### Throttling API calls:

```ruby
# By default, this gem (and maybe your app driving it) will query job/batch statuses at an unbounded rate.  We
# can fix that, e.g.:
salesforce.connection.set_status_throttle(30) # only check status of individual jobs/batches every 30 seconds
```

## Contribute

Feel to fork and send Pull request
