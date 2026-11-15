# frozen_string_literal: true

# == Schema Information
#
# Table name: stripe_webhook_events
#
#  id         :bigint           not null, primary key
#  event_id   :string           not null
#  event_type :string           not null
#  payload    :jsonb            not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
FactoryBot.define do
  factory :stripe_webhook_event, class: "Stripe::WebhookEvent" do
    event_id { "evt_test" }
    event_type { "invoice.paid" }
    payload { {"id" => "evt_test", "type" => "invoice.paid"} }
  end
end
