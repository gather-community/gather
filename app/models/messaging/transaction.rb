# frozen_string_literal: true

# == Schema Information
#
# Table name: messaging_transactions
#
#  id                          :bigint           not null, primary key
#  account_id                  :bigint           not null
#  amount_cents                :integer          not null
#  cluster_id                  :bigint           not null
#  created_at                  :datetime         not null
#  creator_id                  :bigint
#  description                 :string(255)      not null
#  stripe_invoice_line_item_id :string
#  updated_at                  :datetime         not null
#
module Messaging
  # A credit or debit against a Messaging::Account. Top-ups (positive amounts) are created
  # by the Stripe webhook with no creator (i.e. the system). A creator is set for future
  # manual transactions entered by a super admin.
  class Transaction < ApplicationRecord
    DESCRIPTION_MAX_LENGTH = 255

    acts_as_tenant :cluster

    belongs_to :account
    belongs_to :creator, class_name: "User", optional: true

    delegate :community, :community_id, to: :account

    scope :newest_first, -> { order(created_at: :desc) }

    validates :description, presence: true, length: {maximum: DESCRIPTION_MAX_LENGTH}
    validates :amount_cents, presence: true, numericality: {only_integer: true}
  end
end
