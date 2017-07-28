require "rails_helper"

feature "user form", js: true do
  include_context "photo uploads"

  let(:admin) { create(:admin) }
  let(:photographer) { create(:photographer) }
  let(:user) { create(:user, :with_photo) }
  let!(:household) { create(:household, name: "Gingerbread") }
  let!(:household2) { create(:household, name: "Potatoheads") }
  let(:edit_path) { edit_user_path(user) }

  around { |ex| with_user_home_subdomain(actor) { ex.run } }

  before do
    login_as(actor, scope: :user)
  end

  shared_examples_for "editing user" do
    scenario "edit user" do
      visit(edit_user_path(user))
      expect_image_upload(mode: :existing, path: /cooper/)
      drop_in_dropzone(fixture_file_path("chomsky.jpg"))
      expect_image_upload(mode: :dz_preview)
      fill_in("First Name", with: "Zoor")
      click_on("Update User")

      expect_success
      expect(page).to have_title(/Zoor/)
      expect_photo(/chomsky/)
    end
  end

  context "as admin" do
    let(:actor) { admin }

    it_behaves_like "editing user"
    it_behaves_like "photo upload widget"

    scenario "new user" do
      visit(new_user_path)
      expect_no_image_and_drop_file("cooper.jpg")
      click_on("Create User")

      expect_validation_error
      expect_image_upload(mode: :existing, path: /cooper/)
      fill_in("First Name", with: "Foo")
      fill_in("Last Name", with: "Barre")
      fill_in("Email", with: "foo@example.com")
      select2("Ginger", from: "user_household_id")
      fill_in("Mobile", with: "5556667777")
      click_on("Create User")

      expect_success
      expect(page).to have_title(/Foo Barre/)
      expect_photo(/cooper/)
    end

    scenario "editing household" do
      visit(edit_user_path(user))
      click_on("move them to another household")
      select2("Potatoheads", from: "user_household_id")
      click_on("Update User")

      expect_success
      expect(page).to have_css(%Q{a.household[href$="/households/#{household2.id}"]})
    end
  end

  context "as photographer" do
    let(:actor) { photographer }

    scenario "update photo" do
      visit(user_path(user))
      click_on("Edit Photo")
      expect_image_upload(mode: :upload_message)
      drop_in_dropzone(fixture_file_path("chomsky.jpg"))
      expect_image_upload(mode: :dz_preview)
      click_on("Save Photo")
      expect_success
      expect_photo(/chomsky/)
    end
  end

  context "as regular user" do
    let(:actor) { user }

    it_behaves_like "editing user"
  end
end
