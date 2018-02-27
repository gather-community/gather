module People
  class EmergencyContact < ApplicationRecord
    include Phoneable

    acts_as_tenant :cluster

    belongs_to :household
    normalize_attributes :name, :email, :location, :relationship
    handle_phone_types :main, :alt
    validates :name, :main_phone, :location, :relationship, presence: true

    def name_relationship
      "#{name} (#{relationship})"
    end
  end
end
