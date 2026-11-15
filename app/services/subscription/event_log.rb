# frozen_string_literal: true

module Subscription
  # Emits a single greppable log line for subscription/topup events so they're easy to find and audit
  # in BetterStack. Search for "SUBSCRIPTION-EVENT-LINE" (optionally with community_id=<id> or
  # event_name=<name>). Values containing whitespace or quotes are quoted, logfmt-style.
  #
  #   Subscription::EventLog.emit(event_name: "topup_credited", community_id: 5,
  #     description: "Credited messaging topup", amount_cents: 500, invoice_id: "in_123")
  #   => SUBSCRIPTION-EVENT-LINE community_id=5 event_name=topup_credited description="Credited ..." ...
  module EventLog
    PREFIX = "SUBSCRIPTION-EVENT-LINE"

    module_function

    def emit(event_name:, community_id: nil, description: nil, **data)
      fields = {community_id: community_id, event_name: event_name, description: description}
        .merge(data).compact
      formatted = fields.map { |key, value| "#{key}=#{format_value(value)}" }.join(" ")
      Rails.logger.info("#{PREFIX} #{formatted}")
    end

    def format_value(value)
      string = value.to_s
      string.match?(/[\s"]/) ? string.inspect : string
    end
  end
end
