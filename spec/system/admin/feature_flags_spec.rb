# frozen_string_literal: true

require "rails_helper"

describe "admin feature flags dashboard" do
  let!(:actor) { create(:super_admin) }
  let!(:messaging) { create(:feature_flag, name: "messaging", interface: "basic", status: false) }
  let!(:gdrive) { create(:feature_flag, name: "gdrive", interface: "basic", status: true) }
  let!(:jane) { create(:user, first_name: "Jane", last_name: "Doe", email: "jane@example.com") }
  let!(:bob) { create(:user, first_name: "Bob", last_name: "Smith", email: "bob@example.com") }
  let!(:other_cluster) { create(:cluster, name: "Other Cluster") }
  let!(:far_user) do
    with_tenant(other_cluster) do
      community = create(:community, name: "Far Community")
      create(:user, first_name: "Janet", last_name: "Far", email: "far@example.org", community: community)
    end
  end

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  scenario "changing a flag's state from its edit page" do
    visit(admin_feature_flags_path)

    expect(page).to have_content("Feature Flags")
    expect(find("tr", text: "gdrive")).to have_content("Everyone")
    expect(find("tr", text: "messaging")).to have_content("Off")

    click_link("messaging")
    expect(page).to have_title("Feature Flag: messaging")
    click_link("Edit")
    expect(page).to have_content("Edit Feature Flag: messaging")
    # The name can't be changed after creation.
    expect(page).not_to have_field("Name")
    choose("On for everyone")
    click_button("Save")

    expect(page).to have_content("Saved the 'messaging' flag.")
    expect(page).to have_content("Feature Flag: messaging")
    expect(messaging.reload.mode).to eq(:everyone)
  end

  scenario "choosing users on the edit form, which only take effect on save", js: true do
    messaging.update!(mode: :selected_users)
    messaging.users << jane
    visit(edit_admin_feature_flag_path(messaging))

    # The current user is already listed.
    expect(page).to have_css(".user-picker-item", text: "Jane Doe")

    search = find("input[role=combobox]")
    search.fill_in(with: "j")
    expect(page).to have_css(".user-picker-message", text: "Type at least 2 characters")

    # Users from other clusters show up, with their community and email. Users already chosen don't.
    search.fill_in(with: "jan")
    expect(page).to have_css(".user-picker-option", count: 1, text: "Janet Far")
    expect(page).to have_css(".user-picker-details", text: "Far Community · far@example.org")
    find(".user-picker-option", text: "Janet Far").click
    expect(page).to have_css(".user-picker-item", text: "Janet Far")

    # Nothing is saved yet.
    ActsAsTenant.without_tenant { expect(messaging.reload.users).to eq([jane]) }

    # Keyboard selection, and Enter in the search box doesn't submit the form.
    search.fill_in(with: "bob")
    expect(page).to have_css(".user-picker-option", text: "Bob Smith")
    search.send_keys(:down, :enter)
    expect(page).to have_css(".user-picker-item", text: "Bob Smith")
    expect(page).to have_content("Edit Feature Flag: messaging")

    search.fill_in(with: "zzz")
    expect(page).to have_css(".user-picker-message", text: "No matching users")
    search.send_keys(:escape)

    find(".user-picker-item", text: "Jane Doe").find("button[aria-label='Remove']").click
    expect(page).not_to have_css(".user-picker-item", text: "Jane Doe")

    click_button("Save")
    expect(page).to have_content("Saved the 'messaging' flag.")
    expect(find("table.index")).to have_content("Janet Far")
    expect(find("table.index")).to have_content("Far Community")
    expect(page).not_to have_content("Jane Doe")
    ActsAsTenant.without_tenant do
      expect(messaging.reload.users).to contain_exactly(far_user, bob)
      expect(messaging.on?(far_user)).to be(true)
      expect(messaging.on?(jane)).to be(false)
    end
  end

  scenario "the Users field only shows for selected users, and other states delete the users", js: true do
    messaging.update!(mode: :selected_users)
    messaging.users << jane
    visit(edit_admin_feature_flag_path(messaging))

    expect(page).to have_css(".feature_flag_user_ids", visible: :visible)
    choose("On for everyone")
    expect(page).to have_css(".feature_flag_user_ids", visible: :hidden)
    choose("On for selected users")
    expect(page).to have_css(".feature_flag_user_ids", visible: :visible)
    choose("On for everyone")
    click_button("Save")

    expect(page).to have_content("Saved the 'messaging' flag.")
    expect(page).not_to have_content("Selected Users")
    expect(messaging.reload.mode).to eq(:everyone)
    expect(messaging.users).to be_empty
  end

  scenario "creating and deleting a flag", js: true do
    visit(admin_feature_flags_path)
    click_link("New Flag")

    fill_in("Name", with: "Bad Name")
    click_button("Save")
    expect(page).to have_content("must start with a lowercase letter")

    fill_in("Name", with: "new_thing")
    choose("On for selected users")
    click_button("Save")
    expect(page).to have_content("Created the 'new_thing' flag.")
    expect(page).to have_content('FeatureFlag.lookup("new_thing").on?(current_user)')
    expect(FeatureFlag.find_by(name: "new_thing").mode).to eq(:selected_users)

    click_link("Delete")
    expect_modal(text: "Delete the 'new_thing' flag")
    click_modal_button("Delete")
    expect(page).to have_content("Deleted the 'new_thing' flag.")
    expect(FeatureFlag.find_by(name: "new_thing")).to be_nil
  end
end
