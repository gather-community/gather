module Meals
  # A message sent to meal team or diners.
  class Message < ApplicationRecord
    acts_as_tenant(:cluster)

    RECIPIENT_TYPES = %i(team diners all)

    belongs_to :sender, class_name: "User"
    belongs_to :meal

    validates :recipient_type, :body, presence: true

    delegate :name, :email, to: :sender, prefix: true
    delegate :cluster, to: :meal

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
