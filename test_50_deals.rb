#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to run sync on 50 deals locally
# Usage: bundle exec ruby test_50_deals.rb

require_relative '../config/environment'

# Override the master_full_sync to run with 50 deals
system("bundle exec ruby one-time-sync/master_full_sync.rb --start-page=1 --end-page=1 --page-size=50 --verbose")

