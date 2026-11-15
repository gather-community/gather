# frozen_string_literal: true

require "rails_helper"

describe "member types", js: true do
  let(:page_path) { people_member_types_path }
  let(:actor) { create(:admin) }

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  scenario "index, create, update, destroy" do
    visit(page_path)
    expect(page).to have_content("No member types found")
    click_link("Create Member Type")

    fill_in("Name", with: "Squengler")
    click_on("Save")

    expect_success
    click_on("Squengler")

    fill_in("Name", with: "Pongler")
    click_on("Save")

    expect_success
    click_on("Pongler")

    click_link("Delete")
    click_modal_button

    expect_success
    expect(page).to have_content("No member types found")
  end

  describe "confirm modal behavior" do
    let!(:member_type) { create(:member_type, community: actor.community, name: "Squengler") }

    scenario "dismissing the modal cancels the action" do
      visit(edit_people_member_type_path(member_type))

      # Esc dismisses without deleting.
      click_link("Delete")
      expect_modal
      dismiss_modal(via: :escape)
      expect_no_modal

      # The X button dismisses without deleting.
      click_link("Delete")
      expect_modal
      dismiss_modal(via: :x)
      expect_no_modal

      # Record still exists; confirming actually deletes.
      expect(People::MemberType.exists?(member_type.id)).to be(true)
      click_link("Delete")
      click_modal_button
      expect_success
      expect(page).to have_content("No member types found")
    end

    scenario "renders as a bottom sheet on narrow viewports" do
      window = page.current_window
      visit(edit_people_member_type_path(member_type))
      click_link("Delete")
      expect_modal

      # Shrink below the mobile breakpoint; the dialog should anchor to the bottom of the viewport.
      window.resize_to(375, 700)
      anchored = page.evaluate_script(<<~JS)
        (() => {
          const rect = document.querySelector(".gather-modal-dialog").getBoundingClientRect();
          return Math.abs(rect.bottom - window.innerHeight) < 2;
        })()
      JS
      expect(anchored).to be(true)
    ensure
      window.resize_to(1280, 2048)
    end
  end
end
