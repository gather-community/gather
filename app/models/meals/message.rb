module Meals
  # A message sent to meal team or diners.
  class Message < ActiveRecord::Base
    acts_as_tenant(:cluster)

    RECIPIENTS = %w(team diners)

    belongs_to :sender, class_name: "User"
    belongs_to :meal

    validates :sender_id, :meal_id, :recipients, :body, presence: true
  end
end
