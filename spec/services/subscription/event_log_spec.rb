# frozen_string_literal: true

require "rails_helper"

describe Subscription::EventLog do
  it "emits a greppable logfmt line, quoting spaces and dropping nils" do
    expect(Rails.logger).to receive(:info).with(
      "SUBSCRIPTION-EVENT-LINE community_id=5 event_name=topup_credited " \
      "description=\"Credited messaging topup\" amount_cents=500"
    )
    described_class.emit(event_name: "topup_credited", community_id: 5,
      description: "Credited messaging topup", amount_cents: 500, reference: nil)
  end

  it "omits a nil community_id" do
    expect(Rails.logger).to receive(:info).with("SUBSCRIPTION-EVENT-LINE event_name=webhook_arrived")
    described_class.emit(event_name: "webhook_arrived")
  end
end
