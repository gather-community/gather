module FeatureSpecHelpers
  def reload_page
    page.evaluate_script("window.location.reload()")
  end

  # Fills in the given value into the box with given ID, then selects the first matching option.
  # Works with dropdown and inline style select2 boxes. Works with a remote data source.
  def select2(value, from:, type: :dropdown)
    if type == :dropdown
      execute_script("$('#{from}').select2('open')")
      find(".select2-search--dropdown .select2-search__field").set(value)
    elsif type == :inline
      find("#{from} .select2-search__field").click
    end
    # These controls are inserted at the bottom of the DOM so we can't scope them.
    find(".select2-dropdown .select2-results li", text: /#{value}/).click
  end

  def enter_datetime(value, into:)
    find(".#{into} input.datetime_picker").set(value)
  end

  def expect_success
    expect(page).to have_css("div.alert-success", text: /successfully/)
  end

  def expect_validation_error
    expect(page).to have_css("div.alert-danger", text: /Please correct/)
  end

  def expect_image_upload(mode:, path: nil)
    case mode
    when :dz_preview
      expect(page).to have_css("form.dropzone img[data-dz-thumbnail]", visible: true)
      expect(page.find("form.dropzone img[data-dz-thumbnail]")["src"]).to match /base64/
      expect(page).to have_no_css("form.dropzone img.existing", visible: true)
      expect(page).to have_css("form.dropzone a.delete", visible: true)
      expect(page).to have_no_css("form.dropzone .dz-message", visible: true)
    when :existing
      expect(page).not_to have_css("form.dropzone img[data-dz-thumbnail]")
      expect(page).to have_css("form.dropzone img.existing", visible: true)
      expect(page.find("form.dropzone img.existing")["src"]).to match path
      expect(page).to have_css("form.dropzone a.delete", visible: true)
      expect(page).to have_no_css("form.dropzone .dz-message", visible: true)
    when :upload_message
      expect(page).to have_no_css("form.dropzone img[data-dz-thumbnail]", visible: true)
      expect(page).to have_no_css("form.dropzone img.existing", visible: true)
      expect(page).to have_css("form.dropzone .dz-message", visible: true)
    end
  end

  def expect_no_image_upload
    expect(page).to have_css("form.dropzone .dz-message", visible: true)
    expect(page).not_to have_css("form.dropzone img[data-dz-thumbnail]")
    expect(page).to have_no_css("form.dropzone img.existing", visible: true)
    expect(page).to have_no_css("form.dropzone a.delete", visible: true)
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

  def delete_from_dropzone
    find(:css, "form.dropzone a.delete").click
    expect_no_image_upload
  end

  def expect_no_image_and_drop_file(filename)
    expect_no_image_upload
    drop_in_dropzone(fixture_file_path(filename))
    expect_image_upload(mode: :dz_preview)
  end

  def expect_photo(pattern)
    expect(page.find("img.photo")["src"]).to match(pattern)
  end

  def expect_confirm_on_reload
    begin
      accept_confirm { reload_page }
    rescue Capybara::ModalNotFound
      fail("Confirm dialog expected but not shown")
    end
  end

  def expect_no_confirm_on_reload
    begin
      accept_confirm { reload_page }
      fail("Confirm dialog not expected but one was shown")
    rescue Capybara::ModalNotFound
    end
  end

  def stub_omniauth(params)
    OmniAuth.config.test_mode = true
    params.each do |key, hash|
      OmniAuth.config.mock_auth[key] = OmniAuth::AuthHash.new(info: hash)
    end
    yield
    OmniAuth.config.test_mode = false
  end

  def inject_session(hash)
    Warden.on_next_request do |proxy|
      hash.each do |key, value|
        proxy.raw_session[key] = value
      end
    end
  end

  def expect_valid_sign_in_link_and_click
    # Should point to apex domain
    expect(page).to have_css("a[href='http://#{Settings.url.host}:31337/users/auth/google_oauth2']",
      text: "Sign in with Google")

    click_link "Sign in with Google"
  end

  def expect_unselected_option(selector, text)
    expect(page).not_to have_css("#{selector} option[selected]")
    expect(first("#{selector} option")).to have_content(text)
  end

  def be_not_found
    have_content("The page you were looking for doesn't exist")
  end

  def be_forbidden
    have_content("You are not permitted")
  end

  def be_signed_out_root
    have_css("div#blurb", text: "Life is better together.")
  end

  def be_signed_in_root
    have_title("Directory")
  end

  def show_signed_in_user_name(name)
    have_content(name)
  end

  def have_title(title)
    have_css("h1", text: title)
  end

  def have_alert(text)
    have_css(".alert", text: text)
  end

  # Compares the page URL, which is echoed in the footer in test mode only, with the given pattern.
  # Especially useful in cases where you want to wait for the page to load,
  # and there are no other distinguishing things to look for.
  def have_echoed_url(pattern)
    have_css("#url", text: pattern)
  end

  def set_host(host)
    Capybara.app_host = "http://#{host}"
  end

  def select_lens(lens_id, value)
    first(:css, "##{lens_id}").select(value)
  end

  def click_print_button
    first(:css, ".btn-print").click
  end
end
