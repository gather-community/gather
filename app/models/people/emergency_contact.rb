# frozen_string_literal: true

# == Schema Information
#
# Table name: people_emergency_contacts
#
#  id           :integer          not null, primary key
#  alt_phone    :string
#  cluster_id   :integer          not null
#  country_code :string(2)        not null
#  created_at   :datetime         not null
#  email        :string(255)
#  household_id :integer
#  location     :string           not null
#  main_phone   :string           not null
#  name         :string           not null
#  relationship :string           not null
#  updated_at   :datetime         not null
#
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
