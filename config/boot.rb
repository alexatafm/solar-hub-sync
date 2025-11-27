ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

# Skip debug gem functionality in production (but gem is installed to avoid LoadError)
ENV["RUBY_DEBUG_SKIP"] = "1" unless ENV["RAILS_ENV"] == "development" || ENV["RAILS_ENV"] == "test"

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
