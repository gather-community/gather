# frozen_string_literal: true

require "rails_helper"

describe Messaging::CampaignTemplate do
  let(:community) { create(:community, name: "Sunny Hill Cohousing", slug: "sunnyhill") }
  subject(:template) { described_class.new(community) }

  it "fills in the community, its opt-in page and the privacy policy" do
    expect(template.description).to start_with("Sunny Hill Cohousing is a residential cooperative community")
    expect(template.message_flow).to include("sunnyhill.gatherdev.org:31337/notifications")
    expect(template.message_flow).to include("gatherdev.org:31337/about/privacy-policy")
    expect(template.message_flow).to include(Settings.messaging.opt_in_screenshot_url)
    expect(template.samples.size).to eq(3)
    expect(template.samples).to all(start_with("Sunny Hill Cohousing texts"))
  end

  it "builds the Telnyx campaign body" do
    body = template.to_telnyx(brand_id: "b1")
    expect(body).to include(brandId: "b1", usecase: "LOW_VOLUME",
      optoutKeywords: "STOP,UNSUBSCRIBE,CANCEL,END,QUIT,STOPALL",
      helpKeywords: "HELP,INFO", embeddedLink: true, referenceId: "gather-community-#{community.id}")
    expect(body.keys).to include(:sample1, :sample2, :sample3, :messageFlow, :helpMessage, :optoutMessage)
  end

  it "keeps every field within Telnyx's limits even for the longest community name and slug" do
    community.update!(name: "W" * 20, slug: "a" * Community::SLUG_MAX_LENGTH)
    expect(template.help_message.length).to be <= described_class::SAMPLE_MAX
    expect(template.samples.map(&:length).max).to be <= described_class::SAMPLE_MAX
    expect(template.message_flow.length).to be <= described_class::MESSAGE_FLOW_MAX
  end

  it "refuses to render without a public screenshot of the opt-in page" do
    allow(Settings.messaging).to receive(:opt_in_screenshot_url).and_return(nil)
    expect { template.message_flow }.to raise_error(described_class::InvalidTemplateError)
  end
end
