# frozen_string_literal: true

# == Schema Information
#
# Table name: people_emergency_contacts
#
#  id           :integer          not null, primary key
#  alt_phone    :string
#  country_code :string(2)        not null
#  email        :string(255)
#  location     :string           not null
#  main_phone   :string           not null
#  name         :string           not null
#  relationship :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  cluster_id   :integer          not null
#  household_id :integer
#
# Indexes
#
#  index_people_emergency_contacts_on_cluster_id    (cluster_id)
#  index_people_emergency_contacts_on_household_id  (household_id)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (household_id => households.id)
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
