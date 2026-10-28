# frozen_string_literal: true

require "rails_helper"

# The lens-bar Stimulus controller widens a lens dropdown whose selected option doesn't fit, which happens
# in longer languages. A long community name (the most a name can be) exercises the same thing in English.
describe "lens bar", js: true do
  let(:actor) { create(:user) }
  let!(:long_community) { create(:community, name: "Wolfsmoor Gemeinwohl") }

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  scenario "a dropdown keeps its width when its option fits, and grows when it doesn't" do
    visit(households_path)
    expect(lens_node(:community)[:style]).to be_blank

    select_lens(:community, long_community.name)
    expect(page).to have_echoed_url(%r{https?://#{long_community.subdomain}\.})
    width = lens_node(:community)[:style][/width: (\d+)px/, 1].to_i
    expect(width).to be > 155 # The stylesheet's width for the community lens
    expect(width).to be <= 240
  end
end
