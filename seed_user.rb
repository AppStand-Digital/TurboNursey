# seed_user.rb
# frozen_string_literal: true

require_relative "./models/mongo_client"
require_relative "./models/user"

DB.ensure_indexes!
u = User.find_by_email("nurse@example.com") || User.create!(email: "nurse@example.com", password: "Secret123!")
puts "User: #{u[:email]} id=#{u[:_id]}"
puts "Generate QR at: /users/#{u[:_id]}/qr after starting the app."
