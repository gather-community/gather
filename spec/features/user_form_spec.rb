require "rails_helper"

feature "calendar export" do
  let(:admin) { create(:admin) }
  let(:user) { create(:user, :with_photo) }
  let!(:household) { create(:household, name: "Gingerbread") }
  let!(:household2) { create(:household, name: "Potatoheads") }

  shared_examples_for "editing user" do
    scenario "edit user", js: true do
      visit(edit_user_path(user))
      expect_image_upload(mode: :existing, path: /cooper/)
      drop_in_dropzone(fixture_file_path("chomsky.jpg"))
      expect_image_upload(mode: :dz_preview)
      fill_in("First Name", with: "Zoor")
      click_on("Update User")

      expect_validation_success
      expect_title(/Zoor/)
      expect_profile_photo(/chomsky/)
    end
  end

  context "as admin" do
    before do
      login_as(admin, scope: :user)
    end

    it_behaves_like "editing user"

    scenario "new user", js: true do
      visit(new_user_path)
      expect_image_upload(mode: :existing, path: /missing\/users/)
      drop_in_dropzone(fixture_file_path("cooper.jpg"))
      expect_image_upload(mode: :dz_preview)
      click_on("Create User")

      expect_validation_error
      expect_image_upload(mode: :existing, path: /cooper/)
      fill_in("First Name", with: "Foo")
      fill_in("Last Name", with: "Barre")
      fill_in("Email", with: "foo@example.com")
      select2("Ginger", from: "user_household_id")
      fill_in("Mobile Phone", with: "5556667777")
      click_on("Create User")

      expect_validation_success
      expect_title(/Foo Barre/)
      expect_profile_photo(/cooper/)
    end

    scenario "editing household", js: true do
      visit(edit_user_path(user))
      select2("Potatoheads", from: "user_household_id")
      click_on("Update User")

      expect_validation_success
      expect(page).to have_css("li", text: "Household: Potatoheads")
    end

    scenario "deleting photo", js: true do
      # Uploading without saving
      visit(edit_user_path(user))
      expect_image_upload(mode: :existing, path: /cooper/)
      drop_in_dropzone(fixture_file_path("chomsky.jpg"))

      # Uploading and deleting without saving
      visit(edit_user_path(user))
      expect_image_upload(mode: :existing, path: /cooper/)
      drop_in_dropzone(fixture_file_path("chomsky.jpg"))
      delete_from_dropzone

      # Deleting existing photo without saving
      visit(edit_user_path(user))
      expect_image_upload(mode: :existing, path: /cooper/)
      delete_from_dropzone

      # Deleting existing AND saving
      visit(edit_user_path(user))
      expect_image_upload(mode: :existing, path: /cooper/)
      delete_from_dropzone
      click_on("Update User")

      expect_validation_success
      expect_profile_photo(/missing/)
    end
  end

  context "as regular user" do
    before do
      login_as(user, scope: :user)
    end

    it_behaves_like "editing user"
  end
end
