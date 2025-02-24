# frozen_string_literal: true

module Subscription
# == Schema Information
#
# Table name: subscription_intents
#
#  id                   :bigint           not null, primary key
#  address_city         :string           not null
#  address_country      :string           not null
#  address_line1        :string           not null
#  address_line2        :string
#  address_postal_code  :string
#  address_state        :string
#  contact_email        :string           not null
#  currency             :string           not null
#  discount_percent     :decimal(6, 2)
#  months_per_period    :integer          not null
#  payment_method_types :jsonb            not null
#  price_per_user_cents :integer          not null
#  quantity             :integer          not null
#  start_date           :date
#  tier                 :string           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  cluster_id           :bigint           not null
#  community_id         :bigint           not null
#
# Indexes
#
#  index_subscription_intents_on_cluster_id    (cluster_id)
#  index_subscription_intents_on_community_id  (community_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (community_id => communities.id)
#
  # Models a subscription of Gather product itself.
  class Intent < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :community, inverse_of: :subscription_intent

    delegate :name, to: :community, prefix: true

    def registered?
      false
    end

    def incomplete?
      false
    end

    def total_per_invoice
      quantity * price_per_user_cents * months_per_period * (1 - (discount_percent || 0) / 100)
    end

    def future?
      start_date.present? && start_date > Time.zone.today
    end

    def backdated?
      start_date.present? && start_date < Time.zone.today
    end

    def start_date_to_timestamp
      start_date.present? ? Time.zone.parse(start_date.to_s).to_i : nil
    end
  end
end
