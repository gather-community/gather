# frozen_string_literal: true

module Meals
  # Sends just-created meal message to appropriate recipients.
  class MessageJob < ReminderJob
    def perform(message_id)
      with_object_in_cluster_context(klass: Message, id: message_id) do |message|
        message.recipients.each do |recipient|
          # A household's members get one message per language they read email in.
          data = {recipient_id: recipient.id, message_id: message_id}
          each_recipient_locale_group(recipient, kind: :meal_message, data: data) do |group|
            MealMailer.with(recipient: group).send(:"#{message.kind}_message", message, recipient).deliver_now
          end
        end
      end
    end
  end
end
