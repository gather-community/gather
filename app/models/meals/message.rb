module Meals
  # A message sent to meal team or diners.
  class Message < ActiveRecord::Base
    acts_as_tenant(:cluster)

    RECIPIENT_TYPES = %w(team diners)

    belongs_to :sender, class_name: "User"
    belongs_to :meal

    validates :body, presence: true

    def recipient_count
      @recipient_count ||= recipients.size
    end

    # Returns users or households, depending on recipient type.
    def recipients
      case recipient_type
      when "team" then meal.workers
      when "diners" then meal.households
      end
    end
  end
end
