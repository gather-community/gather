module FeatureSpecHelpers
  # Fills in the given value into the box with given ID, then selects the first matching option.
  # Assumes a dropdown-style select2 box. Works with a remote data source.
  def select2(value, from:)
    execute_script("$('##{from}').select2('open')")
    find(".select2-search__field").set(value)
    find(".select2-results li", text: /#{value}/).click
  end

  def expect_validation_success
    expect(page).to have_css("div.alert-success", text: /successfully/)
  end

  def expect_validation_error
    expect(page).to have_css("div.alert-danger", text: /Please correct/)
  end

  def expect_image_upload(mode:, path: nil)
    if mode == :dz_preview
      expect(page).to have_css("form.dropzone img[data-dz-thumbnail]", visible: true)
      expect(page.find("form.dropzone img[data-dz-thumbnail]")["src"]).to match /base64/
      expect(page).to have_css("form.dropzone img.existing", visible: false)
    else
      expect(page).not_to have_css("form.dropzone img[data-dz-thumbnail]")
      expect(page).to have_css("form.dropzone img.existing", visible: true)
      expect(page.find("form.dropzone img.existing")["src"]).to match path
    end
  end

  def drop_in_dropzone(file_path)
    # Generate a fake input selector
    page.execute_script <<-JS
      fakeFileInput = window.$('<input/>').attr(
        {id: 'fakeFileInput', type:'file'}
      ).appendTo('body');
    JS
    # Attach the file to the fake input selector with Capybara
    attach_file("fakeFileInput", file_path)
    # Trigger the fake drop event
    page.execute_script <<-JS
      var e = jQuery.Event('drop', { dataTransfer : { files : [fakeFileInput.get(0).files[0]] } });
      $('.dropzone')[0].dropzone.listeners[0].events.drop(e);
    JS
  end
end
