# models/mongo_client.rb
# frozen_string_literal: true

require "mongo"
require "dotenv/load"

Mongo::Logger.logger.level = Logger::WARN

module DB
  def self.client
    @client ||= Mongo::Client.new( ENV [],database: ENV["SELECTED_DATABASE"])
  end

  def self.db
    client.database
  end

  def self.users
    db[:users]
  end

  def self.rooms
    db[:rooms]
  end

  def self.answers
    db[:answers]
  end

  def self.ensure_indexes!
    users.indexes.create_one({ email: 1 }, unique: true)
    users.indexes.create_one({ login_token: 1 }, unique: true, sparse: true)
    rooms.indexes.create_one({ datetime_stamp: -1 })
    answers.indexes.create_one({ room_id: 1 })
  end
end
