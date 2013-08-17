# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "salesforce_bulk_api/version"

Gem::Specification.new do |s|
  s.name        = "salesforce_bulk_api"
  s.version     = SalesforceBulkApi::VERSION
  s.authors     = ["Yatish Mehta"]
  s.email       = ["yatishmehta27@gmail.com"]
  s.homepage    = "https://github.com/yatishmehta27/salesforce_bulk_api"
  s.summary     = %q{It uses the bulk api of salesforce to communicate with Salesforce CRM}
  s.description = %q{Salesforce Bulk API with governor limits taken care of}

  s.rubyforge_project = "salesforce_bulk_api"
  s.add_dependency(%q<oauth2>, [">= 0.9.1"])
  s.add_dependency(%q<databasedotcom>, [">= 0"])
  s.add_dependency(%q<json>, [">= 0"])
  s.add_dependency(%q<xml-simple>, [">= 0"])
  s.add_development_dependency "rspec"
  s.add_development_dependency "vcr"
  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

end
