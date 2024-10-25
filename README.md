# Salesforce-Bulk-Api

[![Gem Version](https://badge.fury.io/rb/salesforce_bulk_api.png)](http://badge.fury.io/rb/salesforce_bulk_api)

## Overview

`SalesforceBulkApi` is a Ruby wrapper for the Salesforce Bulk API. It is rewritten from [salesforce_bulk](https://github.com/jorgevaldivia/salesforce_bulk) and adds some missing features.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'salesforce_bulk_api'
```

Or install it yourself as:

```
gem install salesforce_bulk_api
```

## Authentication

You can authenticate with Salesforce using two gems: `databasedotcom` or `restforce`. Please check the documentation of the respective gems to learn how to authenticate with Salesforce:

- [Databasedotcom](https://github.com/heroku/databasedotcom)
- [Restforce](https://github.com/ejholmes/restforce)

You can use username/password combo, OmniAuth, or OAuth2.

### Authentication Examples

Using Databasedotcom:

```ruby
require 'salesforce_bulk_api'

client = Databasedotcom::Client.new(
  client_id: SFDC_APP_CONFIG["client_id"],
  client_secret: SFDC_APP_CONFIG["client_secret"]
)
client.authenticate(
  token: " ",
  instance_url: "http://na1.salesforce.com"
)

salesforce = SalesforceBulkApi::Api.new(client)
```

Using Restforce:

```ruby
require 'salesforce_bulk_api'

client = Restforce.new(
  username: SFDC_APP_CONFIG['SFDC_USERNAME'],
  password: SFDC_APP_CONFIG['SFDC_PASSWORD'],
  security_token: SFDC_APP_CONFIG['SFDC_SECURITY_TOKEN'],
  client_id: SFDC_APP_CONFIG['SFDC_CLIENT_ID'],
  client_secret: SFDC_APP_CONFIG['SFDC_CLIENT_SECRET'],
  host: SFDC_APP_CONFIG['SFDC_HOST']
)
client.authenticate!

salesforce = SalesforceBulkApi::Api.new(client)
```

## Usage

### Basic Operations

```ruby
# Insert/Create
new_account = { "name" => "Test Account", "type" => "Other" }
records_to_insert = [new_account]
result = salesforce.create("Account", records_to_insert)
puts "Result: #{result.inspect}"

# Update
updated_account = { "name" => "Test Account -- Updated", "id" => "a00A0001009zA2m" }
records_to_update = [updated_account]
salesforce.update("Account", records_to_update)

# Upsert
upserted_account = { "name" => "Test Account -- Upserted", "External_Field_Name" => "123456" }
records_to_upsert = [upserted_account]
salesforce.upsert("Account", records_to_upsert, "External_Field_Name")

# Delete
deleted_account = { "id" => "a00A0001009zA2m" }
records_to_delete = [deleted_account]
salesforce.delete("Account", records_to_delete)

# Query
res = salesforce.query("Account", "SELECT id, name, createddate FROM Account LIMIT 3")
```

### Helpful Methods

```ruby
# Check status of a job
job = salesforce.job_from_id('a00A0001009zA2m')
puts "Status: #{job.check_job_status.inspect}"
```

### Event Listening

```ruby
# Listen for job creation
salesforce.on_job_created do |job|
  puts "Job #{job.job_id} created!"
end
```

### Fetching Records from a Batch

```ruby
job_id = 'l02A0231009Za8m'
batch_id = 'H24a0708089zA2J'
records = salesforce.get_batch_records(job_id, batch_id)
```

### Throttling API Calls

```ruby
# Set status check interval to 30 seconds
salesforce.connection.set_status_throttle(30)
```

## Contributing

Feel free to fork and send Pull Requests.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.
