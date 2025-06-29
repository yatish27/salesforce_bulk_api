$:.push File.expand_path("../lib", __FILE__)
require "salesforce_bulk_api/version"

Gem::Specification.new do |s|
  s.name = "salesforce_bulk_api"
  s.version = SalesforceBulkApi::VERSION
  s.authors = ["Yatish Mehta"]
  s.email = ["yatish27@users.noreply.github.com"]

  s.homepage = "https://github.com/yatishmehta27/salesforce_bulk_api"
  s.summary = "It uses the bulk api of salesforce to communicate with Salesforce CRM"
  s.description = "Salesforce Bulk API with governor limits taken care of"

  s.add_dependency("json", [">= 0"])
  s.add_dependency("xml-simple", [">= 0"])
  s.add_dependency("csv", [">= 0"])

  s.add_development_dependency "rspec"
  s.add_development_dependency "restforce", "~>  3.0.0"
  s.add_development_dependency "rake", ">= 12.3.3"
  s.add_development_dependency "pry"
  s.add_development_dependency "rubocop"
  s.add_development_dependency "dotenv"

  s.files = `git ls-files`.split("\n")
  s.executables = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  s.require_paths = ["lib"]
end
