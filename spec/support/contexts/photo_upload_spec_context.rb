# frozen_string_literal: true

shared_context "photo uploads" do
  shared_examples_for "photo upload widget" do
    scenario "delete photo" do
      # First upload and save.
      visit(edit_path)
      drop_in_dropzone(fixture_file_path("cooper.jpg"))
      expect_image_upload(state: :new)
      click_button("Save")
      expect_success

      # Now upload different image without saving -- photo should stay cooper
      visit(edit_path)
      expect_image_upload(state: :existing, path: /cooper/)
      drop_in_dropzone(fixture_file_path("chomsky.jpg"))

      # Upload and delete without saving -- should still stay cooper
      visit(edit_path)
      expect_image_upload(state: :existing, path: /cooper/)
      drop_in_dropzone(fixture_file_path("chomsky.jpg"))
      delete_from_dropzone

      # Delete existing photo without saving -- should still stay cooper.
      # Visiting new page will trigger onbeforeunload alert.
      accept_confirm { page.go_back }
      expect_image_upload(state: :existing, path: /cooper/)
      delete_from_dropzone

      # Delete existing AND saving -- should really delete.
      # Visiting new page will trigger onbeforeunload alert.
      accept_confirm { page.go_back }
      expect_image_upload(state: :existing, path: /cooper/)
      delete_from_dropzone
      click_button("Save")

      expect_success
      visit(edit_path)
      expect_no_image_upload
    end

    describe "upload validations" do
      scenario "wrong format", js: true do
        visit(edit_path)
        drop_in_dropzone(fixture_file_path("article.pdf"))
        wait_for_dropzone_upload
        expect(page).to have_css(".dz-error-message", text: /File is incorrect type/)
      end
    end
  end
end
