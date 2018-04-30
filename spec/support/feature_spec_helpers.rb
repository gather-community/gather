# frozen_string_literal: true

module FeatureSpecHelpers
  def reload_page
    page.evaluate_script("window.location.reload()")
  end

  # Fills in the given value into the given select (a Node::Element or CSS selector),
  # then selects the first matching option.
  # If a Node::Element object is provided, it must have a unique ID.
  # Works with dropdown and inline style select2 boxes. Works with a remote data source.
  def select2(value, from:, type: :dropdown)
    if from.is_a?(Capybara::Node::Element)
      select_el = from
      raise "Element must have a unique ID attribute so jQuery can grab it" if select_el[:id].blank?
      css = "##{select_el[:id]}"
    else
      select_el = find(css)
      css = from
    end

    # Get the span element inserted right after the select by select2.
    span_el = select_el.find(:xpath, "following-sibling::span")

    if value == :clear
      span_el.find(".select2-selection__clear").click
    else
      # Several of the elements selected below are inserted at the bottom of the DOM so we can't scope them.
      without do
        if type == :dropdown
          execute_script("$('#{css}').select2('open')")
          find(".select2-search--dropdown .select2-search__field").set(value)
        elsif type == :inline
          span.find(".select2-search__field").click
        end
        find(".select2-dropdown .select2-results li", text: /#{value}/).click
      end
    end
  end

  def pick_datetime(selector, day:, hour:, next_click: "body")
    find("#{selector} .input-group-btn button").click
    within(".bootstrap-datetimepicker-widget") do
      find(".datepicker-days td", text: day).click
      find("[data-action=togglePicker]").click
      sleep 0.25 # If we don't sleep here, the click doesn't seem to register properly.
      find("[data-action=showHours]").click
      sleep 0.25
      find(".timepicker-hours td", text: hour.to_s.rjust(2, "0")).click
    end
    find(next_click).click # Get out of the picker.
  end

  def click_main_nav(name)
    find(".main-nav a", text: name).click
  end

  def click_on_personal_nav(item)
    find(".personal-nav .dropdown-toggle").click
    find(".personal-nav .dropdown-menu a", text: item).click
  end

  def have_signed_in_user(user)
    have_css(".personal-nav a", text: user.name)
  end

  def enter_datetime(value, into:)
    value = I18n.l(Time.parse(value), format: :full_datetime)
    find(".#{into} input.datetime_picker").set(value)
  end

  def enter_date(value, into:)
    value = I18n.l(Date.parse(value), format: :full)
    find(".#{into} input.date_picker").set(value)
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

    # If we don't wait for the upload to finish and another request is processed
    # in the meantime, it can lead to weird failures.
    wait_for_dropzone_upload
  end

  def wait_for_dropzone_upload
    Timeout.timeout(Capybara.default_max_wait_time) do
      loop until page.evaluate_script('!window.uploadView.isUploading()')
    end
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

  def ignore_js_errors
    begin
      yield
    rescue Capybara::Poltergeist::JavascriptError
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

  def select_lens(lens_param_name, value)
    first(:css, "[data-param-name=#{lens_param_name}]").select(value)
  end

  def clear_lenses
    find(".lens-bar a.clear").click
  end

  def click_print_button
    first(:css, ".btn-print").click
  end

  def with_env(vars)
    vars.each_pair { |k, v| ENV[k] = v }
    yield
  ensure
    vars.each_pair { |k, _| ENV.delete(k) }
  end
end
