# models/room.rb
# frozen_string_literal: true

require "time"
require_relative "./mongo_client"

class Room
  REQUIRED = %i[datetime_stamp ward patient nurse_or_hca].freeze

  def self.all
    DB.rooms.find.sort({ datetime_stamp: -1 })
  end

  def self.find(id)
    DB.rooms.find(_id: BSON::ObjectId.from_string(id)).first
  end

  def self.create!(attrs)
    doc = normalize(attrs)
    validate!(doc)
    res = DB.rooms.insert_one(doc.merge(created_at: Time.now, updated_at: Time.now))
    find(res.inserted_id.to_s)
  end

  def self.update!(id, attrs)
    doc = normalize(attrs)
    validate!(doc)
    DB.rooms.update_one({ _id: BSON::ObjectId.from_string(id) }, { "$set" => doc.merge(updated_at: Time.now) })
    find(id)
  end

  def self.destroy!(id)
    oid = BSON::ObjectId.from_string(id)
    DB.answers.delete_many(room_id: oid)
    DB.rooms.delete_one(_id: oid)
  end

  def self.normalize(attrs)
    {
      datetime_stamp: parse_time(attrs["datetime_stamp"] || attrs[:datetime_stamp]),
      ward: (attrs["ward"] || attrs[:ward]).to_s.strip,
      patient: (attrs["patient"] || attrs[:patient]).to_s.strip,
      nurse_or_hca: (attrs["nurse_or_hca"] || attrs[:nurse_or_hca]).to_s.strip,
      mood: (attrs["mood"] || attrs[:mood]).to_s.strip,
      sleeping_awake: (attrs["sleeping_awake"] || attrs[:sleeping_awake]).to_s.strip
    }
  end

  def self.parse_time(val)
    return val if val.is_a?(Time)
    Time.parse(val.to_s)
  rescue
    Time.now
  end

  def self.validate!(doc)
    missing = REQUIRED.select { |k| doc[k].nil? || doc[k].to_s.empty? }
    raise ArgumentError, "Missing: #{missing.join(", ")}" unless missing.empty?
  end
end
