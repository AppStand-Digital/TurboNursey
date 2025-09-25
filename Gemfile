# Gemfile
# frozen_string_literal: true

source "https://rubygems.org"

gem "sinatra", "~> 4.0"          # Web framework
gem "puma", "~> 6.5"             # Rack server for production
gem "rack", ">= 3.0"             # Sinatra 4 runs on Rack 3
gem "dotenv", "~> 3.1"           # Loads ENV from .env
gem "mongo", "~> 2.20"           # MongoDB driver
gem "rqrcode", "~> 2.2"          # QR generation (pure Ruby)
gem "chunky_png", "~> 1.4"       # PNG backend for rqrcode
gem "tilt", ">= 2.0"             # Template engine interface used by Sinatra
gem "rack-protection", ">= 4.0"  # Security helpers for Sinatra 4
gem "rackup"
gem "bson", "~> 5.1"
gem "bigdecimal", "~> 3.2"
gem "bcrypt", "~> 3.1"
gem 'fileutils'
gem 'json'
gem 'bcrypt'
gem 'sinatra-flash'
gem 'rake'

group :development do
  gem "sinatra-contrib", "~> 4.0" # includes sinatra/reloader, etc.
  gem "rerun", "~> 0.14"          # optional: auto-restart on file change
end

group :test do
  gem "rack-test", "~> 2.1"
  gem "rspec", "~> 3.13"
end
