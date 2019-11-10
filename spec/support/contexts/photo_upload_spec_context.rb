shared_context "photo uploads" do
  shared_examples_for "photo upload widget" do
    scenario "delete photo" do
      # First upload and save.
      visit(edit_path)
      drop_in_dropzone(fixture_file_path("cooper.jpg"))
      expect_image_upload(mode: :dz_preview)
      click_button("Save")
      expect_success

      # Now upload different image without saving -- photo should stay cooper
      visit(edit_path)
      expect_image_upload(mode: :existing, path: /cooper/)
      drop_in_dropzone(fixture_file_path("chomsky.jpg"))

      # Upload and delete without saving -- should still stay cooper
      visit(edit_path)
      expect_image_upload(mode: :existing, path: /cooper/)
      drop_in_dropzone(fixture_file_path("chomsky.jpg"))
      delete_from_dropzone

      # Delete existing photo without saving -- should still stay cooper.
      # Visiting new page will trigger onbeforeunload alert.
      accept_alert { visit(edit_path) }
      expect_image_upload(mode: :existing, path: /cooper/)
      delete_from_dropzone

      # Delete existing AND saving -- should really delete.
      # Visiting new page will trigger onbeforeunload alert.
      accept_alert { visit(edit_path) }
      expect_image_upload(mode: :existing, path: /cooper/)
      delete_from_dropzone
      click_button("Save")

      expect_success
      visit(edit_path)
      expect_no_image_upload
    end

    describe "upload validations" do
      context "with smaller size limit" do
        around do |example|
          size = Settings.photos.max_size_mb
          Settings.photos.max_size_mb = 1
          example.run
          Settings.photos.max_size_mb = size
        end

        scenario "too big", js: true do
          visit(edit_path)
          drop_in_dropzone(fixture_file_path("large.jpg"))
          expect(page).to have_css("form.dropzone .dz-error-message", text: /too big/)
        end
      end

      scenario "wrong format", js: true do
        visit(edit_path)
        drop_in_dropzone(fixture_file_path("article.pdf"))
        expect(page).to have_css("form.dropzone .dz-error-message", text: /Photo has incorrect type/)
      end
    end
  end
end
