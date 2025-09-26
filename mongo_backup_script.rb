#!/usr/bin/env ruby
# Tiny Mongo backup: exports each collection to JSONL and gzips it.
# Requirements: gem 'mongo' (already in your Gemfile)
#
# Usage:
#   ruby scripts/mongo_backup_small.rb mongodb://localhost:27017/dbname ./backups
#   # or use env:
#   MONGO_URI="mongodb://localhost:27017/dbname" BACKUP_DIR="./backups" ruby scripts/mongo_backup_small.rb
#
# Restore (manual, per-collection):
#   gunzip -c backups/2025-01-01_120000/users.jsonl.gz | mongoimport --uri "mongodb://..." --collection users --drop --type json --mode=upsert --upsertFields _id
#
# Notes:
#   - Outputs one .jsonl.gz per collection (newline-delimited JSON).
#   - Preserves _id values as they are.
#   - Streams to avoid high memory usage.

require "mongo"
require "json"
require "zlib"
require "fileutils"
require "time"

MONGO_URI  = ARGV[0] || ENV["MONGO_URI"] || "mongodb://127.0.0.1:27017/turbonursey"
BACKUP_DIR = ARGV[1] || ENV["BACKUP_DIR"] || "./backups"

client = Mongo::Client.new(MONGO_URI, server_api: { version: "1" })
db_name = client.database.name
ts = Time.now.utc.strftime("%Y%m%d_%H%M%S")
dst = File.join(BACKUP_DIR, "#{db_name}_#{ts}")
FileUtils.mkdir_p(dst)

puts "Backing up #{db_name} -> #{dst}"

client.database.collection_names.each do |coll_name|
  path = File.join(dst, "#{coll_name}.jsonl.gz")
  count = 0
  Zlib::GzipWriter.open(path) do |gz|
    client[coll_name].find.lazy.each do |doc|
      # Convert BSON::ObjectId to string for portability
      json = JSON.generate(doc.transform_values { |v| v.is_a?(BSON::ObjectId) ? v.to_s : v })
      gz.write(json)
      gz.write("\n")
      count += 1
    end
  end
  puts "  - #{coll_name}: #{count} docs -> #{path}"
end

puts "Done."
