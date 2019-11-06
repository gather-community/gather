# frozen_string_literal: true

require "rails_helper"

describe "protocols", js: true do
  let(:community) { create(:community, settings: {reservations: {kinds: "Official,Personal"}}) }
  let(:actor) { create(:admin, community: community) }

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  context "with no protocols" do
    scenario "index" do
      visit(reservations_protocols_path)
      expect(page).to have_title("Protocols")
      expect(page).to have_content("No protocols found.")
    end
  end

  context "with protocols" do
    let!(:resources) { create_list(:resource, 2, community: community) }
    let!(:protocols) do
      [
        create(:reservation_protocol, community: community, resources: resources,
                                      pre_notice: "Foo notice"),
        create(:reservation_protocol, community: community, kinds: ["Official"],
                                      pre_notice: "Bar notice")
      ]
    end

    scenario "index" do
      visit(reservations_protocols_path)
      expect(page).to have_title("Protocols")
      expect(page).to have_content(protocols[0].resources[0].name)
      expect(page).to have_content("Official")
      expect(page).to have_content("Foo notice")
      expect(page).to have_content("Bar notice")
      expect(page).to have_css("table.index tr", count: 3) # Header plus two rows
    end

    scenario "create and update" do
      visit(reservations_protocols_path)
      click_link("Create Protocol")

      expect(page).to have_content("Type Required")
      fill_in("Name", with: "Stuff")
      select2(resources[0].name, from: "#reservations_protocol_resource_ids", multiple: true)
      select2("Official", from: "#reservations_protocol_kinds", multiple: true)
      expect(page).not_to have_content("Type Required")
      pick_time(".reservations_protocol_fixed_start_time", hour: 2, min: 30, ampm: :pm)
      pick_time(".reservations_protocol_fixed_end_time", hour: 1, min: 30, ampm: :pm)
      fill_in("Max. Advance Time", with: "30")
      click_on("Save")

      click_link("Stuff")
      expect(page).to have_field("Name", with: "Stuff")
      expect(page).to have_css(".select2-selection__choice", text: resources[0].name)
      expect(page).to have_css(".select2-selection__choice", text: "Official")
      expect(page).to have_css(".select2-selection__choice", text: "Official")
      expect(page).to have_field("Fixed Start Time", with: "2:30pm")
      expect(page).to have_field("Fixed End Time", with: "1:30pm")
      expect(page).to have_field("Max. Advance Time", with: "30")
      fill_in("Max. Duration", with: "18000")
      click_on("Save")

      click_link("Stuff")
      expect(page).to have_field("Max. Duration", with: "18000")
    end

    scenario "delete" do
      visit(edit_reservations_protocol_path(protocols.first))
      accept_confirm { click_on("Delete") }
      expect_success
      expect(page).to have_css("table.index tr", count: 2)
    end
  end
end
