# frozen_string_literal: true

#
# Copyright (C) 2014 - present Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.

group :test do
  gem "rails-dom-testing", "2.0.3"
  gem "rails-controller-testing", "1.0.5"

  gem "dotenv", "2.7.5", require: false
  gem "brakeman", require: false
  gem "simplecov", "0.21.2", require: false
    gem "docile", "1.1.5", require: false
  gem "simplecov-rcov", "0.2.3", require: false
  gem "puma", "5.2.2", require: false

  gem "db-query-matchers", "0.10.0"
  gem "rspec", "3.10.0"
  gem "rspec_around_all", "0.2.0"
  gem "rspec-rails", "4.0.1"
  gem "rspec-collection_matchers", "1.2.0"
  gem "rspec-support", "3.10.2"
  gem "rspec-expectations", "3.10.1"
  gem "rspec-mocks", "3.10.2"
  gem "shoulda-matchers", "4.3.0"

  gem "once-ler", "2.0.0"
  gem "sauce_whisk", "0.2.2"

  gem "selenium-webdriver", "~> 4.1.0", require: false
    gem "childprocess", "3.0.0", require: false
  gem "webdrivers", "5.0.0", require: false
  gem "testrailtagging", "0.3.8.7", require: false

  gem "webmock", "3.8.2", require: false
    gem "crack", "0.4.5", require: false
  gem "timecop", "0.9.1"
  gem "jira_ref_parser", "1.0.1"
  gem "headless", "2.3.1", require: false
  gem "escape_code", "0.2", require: false
  gem "luminosity_contrast", "0.2.1"
  gem "pact", "1.57.0", require: false
    gem "pact-support", "1.16.8", require: false
  gem "pact-messages", "0.2.0"
  gem "pact_broker-client", "1.40.0"
  if CANVAS_RAILS6_0
    gem "database_cleaner", "~> 1.5", ">= 1.5.3"
  else
    gem "database_cleaner", "~> 2.0"
  end
  gem "json-schema", "~> 2.8.1"

  gem "parallel_tests"
  gem "rspecq", github: "kyler-instructure/rspecq", ref: "8cea6a3225cf0856a26c6c6b93a5ea5605082aa0"
  gem "flakey_spec_catcher", "~> 0.11.2", require: false
  gem "factory_bot", "6.1.0", require: false
  gem "rspec_junit_formatter", require: false
  # axe-core* versions at or above 4.2 have difficulties with iframes. Keep these at 4.1.0 until fixes are investigated
  gem "axe-core-selenium", "~> 4.1.0", require: false
  gem "axe-core-rspec", "~> 4.1.0", require: false
  gem "axe-core-api", "~> 4.1.0", require: false
  gem "stormbreaker", "0.0.5", require: false

  # performance tools for instrumenting rspec tests
  gem "stackprof"

  gem "crystalball", "0.7.0", require: false
end
