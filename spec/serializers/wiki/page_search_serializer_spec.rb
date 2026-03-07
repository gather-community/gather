# frozen_string_literal: true

require "rails_helper"

describe Wiki::PageSearchSerializer do
  let(:community) { Defaults.community }
  let(:page) do
    create(:wiki_page, community: community, title: "Solar Panels", content: "Lots of sun.")
  end

  subject(:data) { described_class.new(page).as_json }

  it "includes required fields" do
    expect(data).to include(
      "id" => page.id,
      "community_id" => community.id,
      "title" => "Solar Panels",
      "content" => "Lots of sun.",
      "slug" => page.slug
    )
  end

  it "includes updated_at" do
    expect(data).to have_key("updated_at")
  end
end
