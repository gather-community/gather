# frozen_string_literal: true

module Meals
  # Sends just-created meal message to appropriate recipients.
  class MessageJob < ReminderJob
    def perform(message_id)
      with_object_in_community_context(Message, message_id) do |message|
        message.recipients.each do |recipient|
          MealMailer.send(:"#{message.kind}_message", message, recipient).deliver_now
        end
      end
    end
  end
end
