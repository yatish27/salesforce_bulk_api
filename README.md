# Salesforce-Bulk-Api

[![Gem Version](https://badge.fury.io/rb/salesforce_bulk_api.png)](http://badge.fury.io/rb/salesforce_bulk_api)

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Authentication](#authentication)
- [Usage](#usage)
  - [Basic Operations](#basic-operations)
  - [Job Management](#job-management)
  - [Event Listening](#event-listening)
  - [Retrieving Batch Records](#retrieving-batch-records)
  - [API Call Throttling](#api-call-throttling)
- [Contributing](#contributing)
- [License](#license)

## Overview

`SalesforceBulkApi` is a Ruby wrapper for the Salesforce Bulk API. It is rewritten from [salesforce_bulk](https://github.com/jorgevaldivia/salesforce_bulk) and adds several missing features, making it easier to perform bulk operations with Salesforce from Ruby applications.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'salesforce_bulk_api'
```

And then execute:

```
bundle install
```

Or install it directly:

```
gem install salesforce_bulk_api
```

## Authentication

You can authenticate with Salesforce using either `databasedotcom` or `restforce` gems. Both support various authentication methods including username/password, OmniAuth, and OAuth2.

Please refer to the documentation of these gems for detailed authentication options:

- [Databasedotcom](https://github.com/heroku/databasedotcom)
- [Restforce](https://github.com/ejholmes/restforce)

### Authentication Examples

#### Using Databasedotcom:

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

#### Using Restforce:

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

#### Create/Insert Records

```ruby
new_account = { "name" => "Test Account", "type" => "Other" }
records_to_insert = [new_account]
result = salesforce.create("Account", records_to_insert)
puts "Result: #{result.inspect}"
```

#### Update Records

```ruby
updated_account = { "name" => "Test Account -- Updated", "id" => "a00A0001009zA2m" }
records_to_update = [updated_account]
salesforce.update("Account", records_to_update)
```

#### Upsert Records

```ruby
upserted_account = { "name" => "Test Account -- Upserted", "External_Field_Name" => "123456" }
records_to_upsert = [upserted_account]
salesforce.upsert("Account", records_to_upsert, "External_Field_Name")
```

#### Delete Records

```ruby
deleted_account = { "id" => "a00A0001009zA2m" }
records_to_delete = [deleted_account]
salesforce.delete("Account", records_to_delete)
```

#### Query Records

```ruby
res = salesforce.query("Account", "SELECT id, name, createddate FROM Account LIMIT 3")
```

### Job Management

You can check the status of a job using its ID:

```ruby
job = salesforce.job_from_id('a00A0001009zA2m')
puts "Status: #{job.check_job_status.inspect}"
```

### Event Listening

You can listen for job creation events:

```ruby
salesforce.on_job_created do |job|
  puts "Job #{job.job_id} created!"
end
```

### Retrieving Batch Records

Fetch records from a specific batch in a job:

```ruby
job_id = 'l02A0231009Za8m'
batch_id = 'H24a0708089zA2J'
records = salesforce.get_batch_records(job_id, batch_id)
```

### API Call Throttling

You can control how frequently status checks are performed:

```ruby
# Set status check interval to 30 seconds
salesforce.connection.set_status_throttle(30)
```

## Contributing

We welcome contributions to improve this gem. Feel free to:

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -am 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Create a new Pull Request

## License

This project is licensed under the MIT License, Copyright (c) 2025 - see the [LICENCE](LICENCE) file for details.
