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
    # The controller sets the width when it connects, just after the page loads.
    expect(page).to have_css("select[data-param-name=community][style*=width]")
    width = lens_node(:community)[:style][/width: (\d+)px/, 1].to_i
    expect(width).to be > 155 # The stylesheet's width for the community lens
    expect(width).to be <= 240
  end

  scenario "the lenses move below the title when they no longer fit beside it" do
    visit(users_path)
    expect(page).to have_css(".lens-bar.upper select")
    expect(page).not_to have_css(".title-and-buttons.lenses-below")

    # Make every selected option too long to fit, then reconnect the controllers so they size again.
    page.execute_script(<<~JS)
      document.querySelectorAll(".lens-bar select").forEach((s) => { s.options[s.selectedIndex].text = "x".repeat(60); });
      const bars = document.querySelectorAll(".lens-bar");
      bars.forEach((b) => b.removeAttribute("data-controller"));
      setTimeout(() => bars.forEach((b) => b.setAttribute("data-controller", "lens-bar")), 50);
    JS

    expect(page).to have_css(".title-and-buttons.lenses-below")
    expect(page).to have_css(".lens-bar.lower select[data-param-name=community][style*=width]")
    root = "document.documentElement"
    expect(page.evaluate_script("#{root}.scrollWidth - #{root}.clientWidth")).to eq(0)
  end
end
