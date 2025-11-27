# frozen_string_literal: true

# == Schema Information
#
# Table name: meal_messages
#
#  id             :integer          not null, primary key
#  body           :text             not null
#  cluster_id     :integer          not null
#  created_at     :datetime         not null
#  kind           :string           default("normal"), not null
#  meal_id        :integer          not null
#  recipient_type :string           not null
#  sender_id      :integer          not null
#  updated_at     :datetime         not null
#
module Meals
  # A message sent to meal team or diners.
  class Message < ApplicationRecord
    acts_as_tenant :cluster

    RECIPIENT_TYPES = %i[team diners all].freeze

    belongs_to :sender, class_name: "User"
    belongs_to :meal, class_name: "Meals::Meal"

    validates :recipient_type, :body, presence: true

    delegate :name, :email, to: :sender, prefix: true
    delegate :community, :community_id, :cluster, to: :meal

    def recipient_count
      @recipient_count ||= recipients.size
    end

    # Returns users or households, depending on recipient type.
    def recipients
      case recipient_type
      when "team" then workers
      when "diners" then households
      when "all" then workers + households
      end
    end

    def cancellation?
      kind == "cancellation"
    end

    private

    def workers
      meal.workers
    end

    def households
      meal.signups.map(&:household)
    end
  end
end
