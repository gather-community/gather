class People::EmergencyContact < ActiveRecord::Base
  include Phoneable

  belongs_to :household
  normalize_attributes :name, :email, :location, :relationship
  handle_phone_types :main, :alt
  validates :name, :main_phone, :location, :relationship, presence: true

  def name_relationship
    "#{name} (#{relationship})"
  end

  def to_s
    "#{name_relationship} - #{location}, " << (phones.map(&:formatted) << email).compact.join(", ")
  end
end
