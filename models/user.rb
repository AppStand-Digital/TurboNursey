# models/user.rb
# frozen_string_literal: true

class User < ActiveRecord::Base
  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
end
