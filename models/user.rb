# models/user.rb
# frozen_string_literal: true

require "securerandom"
require "bcrypt"
require_relative "./mongo_client"

class User
  def self.find_by_id(id)
    DB.users.find(_id: BSON::ObjectId.from_string(id)).first
  end

  def self.find_by_email(email)
    DB.users.find(email: email).first
  end

  def self.find_by_nickname(nickname)
    DB.users.find(nickname: nickname).first
  end

  def self.create!(email:, password: ,nickname:,nurse:,hca:,admin:)
    password_hash = BCrypt::Password.create(password)
    doc = { email: email.downcase, password_hash:, created_at: Time.now, nickname: nickname,nurse: nurse,hca:hca,admin:admin }
    res = DB.users.insert_one(doc)
    DB.users.find(_id: res.inserted_id).first
  end

  def self.generate_login_token!(user_id)
    token = SecureRandom.hex(16)
    DB.users.update_one(
      { _id: user_id.is_a?(BSON::ObjectId) ? user_id : BSON::ObjectId.from_string(user_id) },
      { "$set" => { login_token: token, login_token_issued_at: Time.now } }
    )
    token
  end

  def self.consume_login_token!(token)
    user = DB.users.find(login_token: token).first
    return nil unless user
    DB.users.update_one({ _id: user[:_id] }, { "$unset" => { login_token: "", login_token_issued_at: "" } })
    user
  end

  def self.valid_password?(user, password)
    return false unless user && user[:password_hash]
    BCrypt::Password.new(user[:password_hash]) == password
  end
end
