# models/answer.rb
# frozen_string_literal: true

require_relative "./mongo_client"

class Answer
  def self.for_room(room_id)
    DB.answers.find(room_id: BSON::ObjectId.from_string(room_id)).sort({ created_at: 1 })
  end

  def self.add!(room_id:, question:, response:)
    DB.answers.insert_one({
      room_id: BSON::ObjectId.from_string(room_id),
      question: question.to_s,
      response: response.to_s,
      created_at: Time.now
    })
  end

  def self.delete!(id)
    DB.answers.delete_one(_id: BSON::ObjectId.from_string(id))
  end
end
