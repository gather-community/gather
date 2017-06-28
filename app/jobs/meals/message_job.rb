# Sends just-created meal message to appropriate recipients.
module Meals
  class MessageJob < ReminderJob
    attr_reader :message_id

    def initialize(message_id)
      @message_id = message_id
    end

    def perform
      ActsAsTenant.with_tenant(message.cluster) do
        message.recipients.each { |recipient| MealMailer.send(mailer_method, message, recipient) }
      end
    end

    private

    def message
      @message ||= ActsAsTenant.without_tenant do
        Message.find(message_id).tap(&:cluster)
      end
    end

    def mailer_method
      :"#{message.recipient_type.singularize}_message"
    end
  end
end
