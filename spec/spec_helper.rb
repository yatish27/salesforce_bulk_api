require "rubygems"
require "bundler/setup"
require "salesforce_bulk_api"

require "dotenv"
Dotenv.load

RSpec.configure do |c|
  c.filter_run focus: true
  c.run_all_when_everything_filtered = true
end
