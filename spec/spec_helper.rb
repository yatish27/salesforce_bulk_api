require 'rubygems'
require 'bundler/setup'
#require 'webmock/rspec'
#require 'vcr'
require 'salesforce_bulk_api'


# enable this and record the test requests using a SF developer org.
# VCR.configure do |c|
#   c.cassette_library_dir = 'spec/cassettes'
#   c.hook_into :webmock
# end