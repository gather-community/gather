# Sends just-created meal message to appropriate recipients.
module Meals
  class MessageJob < ReminderJob
    attr_reader :message_id

    delegate :community, to: :message

    def initialize(message_id)
      @message_id = message_id
    end

    def perform
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
