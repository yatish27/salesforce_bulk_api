require 'rubygems'
require 'bundler/setup'
#require 'webmock/rspec'
#require 'vcr'
require 'salesforce_bulk_api'

RSpec.configure do |c|
  c.filter_run :focus => true
  c.run_all_when_everything_filtered = true
end

# enable this and record the test requests using a SF developer org.
# VCR.configure do |c|
#   c.cassette_library_dir = 'spec/cassettes'
#   c.hook_into :webmock
# end