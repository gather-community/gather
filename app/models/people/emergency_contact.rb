class People::EmergencyContact < ActiveRecord::Base
  include Phoneable

  belongs_to :household
  normalize_attributes :name, :email, :location, :relationship
  handle_phone_types :main, :alt
  validates :name, :main_phone, :location, :relationship, presence: true

  def to_s
    "#{name} (#{relationship}) - #{location}, " <<
      [format_phone(:main), format_phone(:alt), email].compact.join(", ")
  end
end
