# Salesforce-Bulk-Api

[![Gem Version](https://badge.fury.io/rb/salesforce_bulk_api.png)](http://badge.fury.io/rb/salesforce_bulk_api)

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Authentication](#authentication)
- [Usage](#usage)
  - [Basic Operations](#basic-operations)
  - [Method Parameters](#method-parameters)
  - [Getting Results](#getting-results)
  - [Null Value Handling](#null-value-handling)
  - [Job Management](#job-management)
  - [Batch Operations](#batch-operations)
  - [Event Listening](#event-listening)
  - [API Call Throttling](#api-call-throttling)
  - [Monitoring and Counters](#monitoring-and-counters)
- [Error Handling](#error-handling)
- [Advanced Features](#advanced-features)
- [Contributing](#contributing)
- [License](#license)

## Overview

`SalesforceBulkApi` is a Ruby wrapper for the Salesforce Bulk API. It is rewritten from [salesforce_bulk](https://github.com/jorgevaldivia/salesforce_bulk) and adds several missing features, making it easier to perform bulk operations with Salesforce from Ruby applications.

Key features:
- Support for all Bulk API operations (create, update, upsert, delete, query)
- Comprehensive error handling
- Job and batch status monitoring
- Event listening for job lifecycle
- API call throttling and monitoring
- Performance optimized string concatenation for large batches

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

# Basic usage
result = salesforce.create("Account", records_to_insert)

# With response and custom batch size
result = salesforce.create("Account", records_to_insert, true, false, [], 5000)
```

#### Update Records

```ruby
updated_account = { "name" => "Test Account -- Updated", "id" => "a00A0001009zA2m" }
records_to_update = [updated_account]

# Basic usage
salesforce.update("Account", records_to_update)

# With null handling
salesforce.update("Account", records_to_update, true, true, ["Phone"])
```

#### Upsert Records

```ruby
upserted_account = { "name" => "Test Account -- Upserted", "External_Field_Name" => "123456" }
records_to_upsert = [upserted_account]

# Basic usage
salesforce.upsert("Account", records_to_upsert, "External_Field_Name")

# With all options
result = salesforce.upsert("Account", records_to_upsert, "External_Field_Name", true, false, [], 10000, 3600)
```

#### Delete Records

```ruby
deleted_account = { "id" => "a00A0001009zA2m" }
records_to_delete = [deleted_account]

# Basic usage
salesforce.delete("Account", records_to_delete)

# With response
result = salesforce.delete("Account", records_to_delete, true)
```

#### Query Records

```ruby
result = salesforce.query("Account", "SELECT id, name, createddate FROM Account LIMIT 3")
puts "Records found: #{result["batches"][0]["response"].length}"
```

### Method Parameters

All bulk operation methods support additional parameters for fine-tuned control:

#### Complete Method Signatures:

```ruby
# CREATE
salesforce.create(sobject, records, get_response=false, send_nulls=false, no_null_list=[], batch_size=10000, timeout=1500)

# UPDATE  
salesforce.update(sobject, records, get_response=false, send_nulls=false, no_null_list=[], batch_size=10000, timeout=1500)

# UPSERT
salesforce.upsert(sobject, records, external_field, get_response=false, send_nulls=false, no_null_list=[], batch_size=10000, timeout=1500)

# DELETE
salesforce.delete(sobject, records, get_response=false, batch_size=10000, timeout=1500)

# QUERY
salesforce.query(sobject, query_string, batch_size=10000, timeout=1500)
```

#### Parameter Descriptions:

- **`get_response`** (Boolean): Whether to return batch processing results (default: false)
- **`send_nulls`** (Boolean): Whether to send null/empty values to Salesforce (default: false)
- **`no_null_list`** (Array): Fields to exclude from null value handling when `send_nulls` is true
- **`batch_size`** (Integer): Number of records per batch (default: 10000, max: 10000)
- **`timeout`** (Integer): Timeout in seconds for job completion (default: 1500)

### Getting Results

When `get_response` is set to true, you'll receive detailed results:

```ruby
result = salesforce.create("Account", records, true)

# Access job information
puts "Job ID: #{result['job_id']}"
puts "Job state: #{result['state']}"

# Access batch results
result["batches"].each_with_index do |batch, index|
  puts "Batch #{index + 1}:"
  puts "  State: #{batch['state'][0]}"
  puts "  Records processed: #{batch['numberRecordsProcessed'][0]}"
  
  if batch["response"]
    batch["response"].each do |record|
      if record["success"] == ["true"]
        puts "  ✓ Success: #{record['id'][0]}"
      else
        puts "  ✗ Error: #{record['errors'][0]['message'][0]}"
      end
    end
  end
end
```

### Null Value Handling

Control how null and empty values are handled:

```ruby
records = [
  { "Id" => "001...", "Name" => "Test", "Phone" => "", "Website" => nil }
]

# Send nulls for empty/nil fields, except for Phone
result = salesforce.update("Account", records, true, true, ["Phone"])

# This will:
# - Set Website to NULL in Salesforce (because it's nil)
# - Leave Phone unchanged (because it's in no_null_list)
# - Update Name normally
```

### Job Management

#### Get Job by ID

```ruby
job = salesforce.job_from_id('750A0000001234567')
status = job.check_job_status
puts "Job state: #{status['state'][0]}"
puts "Batches total: #{status['numberBatchesTotal'][0]}"
```

#### Check Job Status

```ruby
job = salesforce.job_from_id(job_id)
status = job.check_job_status

puts "Job Information:"
puts "  State: #{status['state'][0]}"
puts "  Object: #{status['object'][0]}"
puts "  Operation: #{status['operation'][0]}"
puts "  Total Batches: #{status['numberBatchesTotal'][0]}"
puts "  Completed Batches: #{status['numberBatchesCompleted'][0]}"
puts "  Failed Batches: #{status['numberBatchesFailed'][0]}"
```

### Batch Operations

#### Check Batch Status

```ruby
job = salesforce.job_from_id(job_id)
batch_status = job.check_batch_status(batch_id)

puts "Batch Information:"
puts "  State: #{batch_status['state'][0]}"
puts "  Records Processed: #{batch_status['numberRecordsProcessed'][0]}"
puts "  Records Failed: #{batch_status['numberRecordsFailed'][0]}"
```

#### Retrieve Batch Records

```ruby
job = salesforce.job_from_id(job_id)
records = job.get_batch_records(batch_id)

puts "Batch Records:"
records.each do |record|
  puts "  #{record.inspect}"
end
```

#### Get Batch Results

```ruby
job = salesforce.job_from_id(job_id)
results = job.get_batch_result(batch_id)

results.each do |result|
  if result["success"] == ["true"]
    puts "Success: Record ID #{result['id'][0]}"
  else
    puts "Failed: #{result['errors'][0]['message'][0]}"
  end
end
```

### Event Listening

Listen for job creation events:

```ruby
salesforce.on_job_created do |job|
  puts "Job #{job.job_id} created for #{job.operation} on #{job.sobject}!"
  
  # You can perform additional operations here
  # like logging, notifications, etc.
end

# Now when you create/update/etc, the listener will be called
result = salesforce.create("Account", records)
```

### API Call Throttling

Control the frequency of status checks to avoid hitting API limits:

```ruby
# Set status check interval to 30 seconds (default is 5 seconds)
salesforce.connection.set_status_throttle(30)

# Check current throttle setting
puts "Current throttle: #{salesforce.connection.get_status_throttle} seconds"
```

### Monitoring and Counters

Track API usage and operations:

```ruby
# Get operation counters
counters = salesforce.counters
puts "API Usage: #{counters}"
# => {:http_get=>15, :http_post=>8, :upsert=>2, :update=>1, :create=>3, :delete=>0, :query=>2}

# Reset counters
salesforce.reset_counters
```

## Error Handling

The gem provides comprehensive error handling:

```ruby
begin
  result = salesforce.create("Account", records, true)
  
  # Check for batch-level errors
  result["batches"].each do |batch|
    if batch["state"][0] == "Failed"
      puts "Batch failed: #{batch["stateMessage"][0]}"
    end
  end
  
rescue SalesforceBulkApi::Job::SalesforceException => e
  puts "Salesforce API error: #{e.message}"
  # Handle API-level errors (invalid objects, fields, etc.)
  
rescue SalesforceBulkApi::JobTimeout => e
  puts "Job timed out: #{e.message}"
  # Handle timeout errors - job took longer than specified timeout
  
rescue => e
  puts "Unexpected error: #{e.message}"
  # Handle other errors (network issues, authentication, etc.)
end
```

### Common Error Scenarios

```ruby
# Invalid field names
begin
  records = [{ "InvalidField__c" => "value" }]
  salesforce.create("Account", records, true)
rescue SalesforceBulkApi::Job::SalesforceException => e
  puts "Field error: #{e.message}"
end

# Malformed record IDs
begin
  records = [{ "Id" => "invalid_id" }]
  salesforce.update("Account", records, true)
rescue => e
  # This might not raise immediately - check batch results
  result = salesforce.update("Account", records, true)
  failed_records = result["batches"][0]["response"].select { |r| r["success"] == ["false"] }
  failed_records.each { |r| puts "Failed: #{r['errors'][0]['message'][0]}" }
end
```

## Advanced Features

### Relationship Fields

You can work with relationship fields using dot notation:

```ruby
# Create records with relationship data
records = [
  {
    "Name" => "Test Account",
    "Parent.Name" => "Parent Account Name",
    "Owner.Email" => "owner@example.com"
  }
]

result = salesforce.create("Account", records, true)
```

### Special Data Types

The gem automatically handles various data types:

```ruby
records = [
  {
    "Name" => "Test Account",
    "AnnualRevenue" => 1000000,                    # Numbers
    "IsActive__c" => true,                         # Booleans  
    "LastModifiedDate" => Time.now,                # Timestamps (converted to ISO8601)
    "Description" => "Text with <special> chars"   # XML encoding handled automatically
  }
]
```

### Large Dataset Handling

For large datasets, the gem automatically handles batching:

```ruby
# This will be automatically split into multiple batches of 10,000 records each
large_dataset = (1..50000).map { |i| { "Name" => "Account #{i}" } }

result = salesforce.create("Account", large_dataset, true, false, [], 10000, 7200) # 2 hour timeout
puts "Created #{result['batches'].length} batches"
```

### Custom Batch Sizes

Optimize for your use case:

```ruby
# Smaller batches for complex records
complex_records = [...]
salesforce.create("CustomObject__c", complex_records, true, false, [], 2000)

# Larger batches for simple records (up to 10,000)
simple_records = [...]
salesforce.create("Account", simple_records, true, false, [], 10000)
```

## Contributing

We welcome contributions to improve this gem. Feel free to:

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -am 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Create a new Pull Request

### Development Setup

```bash
git clone https://github.com/yatish27/salesforce_bulk_api.git
cd salesforce_bulk_api
bundle install

# Copy environment template
cp .env.sample .env
# Edit .env with your Salesforce credentials

# Run tests
bundle exec rspec

# Run RuboCop
bundle exec rubocop
```

## License

This project is licensed under the MIT License, Copyright (c) 2025 - see the [LICENCE](LICENCE) file for details.