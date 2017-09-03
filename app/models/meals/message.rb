module Meals
  # A message sent to meal team or diners.
  class Message < ActiveRecord::Base
    acts_as_tenant(:cluster)

    RECIPIENT_TYPES = %w(team diners)

    belongs_to :sender, class_name: "User"
    belongs_to :meal

    validates :body, presence: true

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

    private

    def workers
      meal.workers - [sender]
    end

    def households
      meal.signups.map(&:household)
    end
  end
end
