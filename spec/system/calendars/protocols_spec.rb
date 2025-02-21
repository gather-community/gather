# frozen_string_literal: true

require "rails_helper"

describe "protocols", js: true do
  let(:community) { create(:community, settings: {calendars: {kinds: "Official,Personal"}}) }
  let(:actor) { create(:admin, community: community) }

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  context "with no protocols" do
    scenario "index" do
      visit(calendars_protocols_path)
      expect(page).to have_title("Protocols")
      expect(page).to have_content("No protocols found.")
    end
  end

  context "with protocols" do
    let!(:calendars) { create_list(:calendar, 2, community: community) }
    let!(:inactive_calendar) { create(:calendar, :inactive, community: community) }
    let!(:sys_calendar) { create(:community_meals_calendar, community: community) }
    let!(:protocols) do
      [
        create(:calendar_protocol, community: community, calendars: calendars,
          pre_notice: "Foo notice"),
        create(:calendar_protocol, community: community, kinds: ["Official"],
          pre_notice: "Bar notice")
      ]
    end

    scenario "index" do
      visit(calendars_protocols_path)
      expect(page).to have_title("Protocols")
      expect(page).to have_content(protocols[0].calendars[0].name)
      expect(page).to have_content("Official")
      expect(page).to have_content("Foo notice")
      expect(page).to have_content("Bar notice")
      expect(page).to have_css("table.index tr", count: 3) # Header plus two rows
    end

    scenario "create and update" do
      visit(calendars_protocols_path)
      click_link("Create Protocol")

      expect(page).to have_content("Type Required")
      fill_in("Name", with: "Stuff")
      cal_select = "#calendars_protocol_calendar_ids"
      expect_no_select2_match(sys_calendar.name, from: cal_select, multiple: true)
      expect_no_select2_match(inactive_calendar.name, from: cal_select, multiple: true)
      select2(calendars[0].name, from: cal_select, multiple: true)
      select2("Official", from: "#calendars_protocol_kinds", multiple: true)
      expect(page).not_to have_content("Type Required")
      pick_time(".calendars_protocol_fixed_start_time", hour: 2, min: 30, ampm: :pm,
        next_click: "div.title-and-buttons")
      pick_time(".calendars_protocol_fixed_end_time", hour: 1, min: 30, ampm: :pm,
        next_click: "div.title-and-buttons")
      fill_in("Max. Advance Time", with: "30")
      click_button("Save")

      click_link("Stuff")
      expect(page).to have_field("Name", with: "Stuff")
      expect(page).to have_css(".select2-selection__choice", text: calendars[0].name)
      expect(page).to have_css(".select2-selection__choice", text: "Official")
      expect(page).to have_css(".select2-selection__choice", text: "Official")
      expect(page).to have_field("Fixed Start Time", with: "2:30pm")
      expect(page).to have_field("Fixed End Time", with: "1:30pm")
      expect(page).to have_field("Max. Advance Time", with: "30")
      fill_in("Max. Duration", with: "18000")
      click_button("Save")

      click_link("Stuff")
      expect(page).to have_field("Max. Duration", with: "18000")
    end

    scenario "delete" do
      visit(edit_calendars_protocol_path(protocols.first))
      accept_confirm { click_on("Delete") }
      expect_success
      expect(page).to have_css("table.index tr", count: 2)
    end
  end

  context "with protocol with inactive calendar" do
    let!(:calendar) { create(:calendar, :inactive, community: community, name: "Log Drivings") }
    let!(:protocol) do
      create(:calendar_protocol, community: community, calendars: [calendar], name: "Stuff",
        pre_notice: "Foo notice")
    end

    scenario "does not lose calendar" do
      visit(edit_calendars_protocol_path(protocol))
      expect(page).to have_content("Log Drivings (Inactive)")
      click_on("Save")
      expect_success
      click_on("Stuff")
      expect(page).to have_content("Log Drivings (Inactive)")
    end
  end
end
