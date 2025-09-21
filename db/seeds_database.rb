# db/seeds.rb
# frozen_string_literal: true

require_relative "../app"

User.create!(name: "Alice", email: "alice@example.com")
User.create!(name: "Bob", email: "bob@example.com")
