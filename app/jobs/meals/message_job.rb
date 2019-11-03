# frozen_string_literal: true

module Meals
  # Sends just-created meal message to appropriate recipients.
  class MessageJob < ReminderJob
    attr_accessor :message_id

    delegate :community, to: :message

    def perform(message_id)
      self.message_id = message_id
      with_community(community) do
        message.recipients.each do |recipient|
          MealMailer.send(:"#{message.kind}_message", message, recipient).deliver_now
        end
      end
    end

    private

    def message
      @message ||= ActsAsTenant.without_tenant do
        Message.find(message_id).tap(&:cluster)
      end
    end
  end
end
