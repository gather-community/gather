class People::EmergencyContact < ActiveRecord::Base
  include Phoneable

  belongs_to :household

  normalize_attributes :name, :email, :location, :relationship
  handle_phone_types :main, :alt

  validates :name, :main_phone, :location, :relationship, presence: true
end
