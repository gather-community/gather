# frozen_string_literal: true

module SystemSpecHelpers
  def reload_page
    page.evaluate_script("window.location.reload()")
  end

  # Temporarily undoes any within scopes.
  def with_top_level_scope(&)
    within(Capybara::Node::Document.new(page, page.driver), &)
  end

  # Fills in the given value into the given select (a Node::Element or CSS selector),
  # then selects the first matching option.
  # If a Node::Element object is provided, it must have a unique ID.
  # Works with single and multiple style select2 boxes. Works with a remote data source.
  # Use a Node::Element argument if calling from a within block -- the CSS variant may
  # select the wrong element.
  def select2(value, from:, multiple: false)
    prep_select2(value, from: from, multiple: multiple) do
      find(".select2-dropdown .select2-results li", text: /#{value}/).click
    end
  end

  def expect_no_select2_match(value, from:, multiple: false)
    prep_select2(value, from: from, multiple: multiple) do
      expect { find(".select2-dropdown .select2-results li", text: /#{value}/) }
        .to raise_error(Capybara::ElementNotFound)
      find("body").click
    end
  end

  # Prepares select2 for finding the element and clicking it. Yields when it's time to shine.
  def prep_select2(value, from:, multiple:)
    if from.is_a?(Capybara::Node::Element)
      select_el = from
      raise "Element must have a unique ID attribute so jQuery can grab it" if select_el[:id].blank?

      css = "##{select_el[:id]}"
    else
      css = from
      select_el = find(css)
    end

    # Get the span element inserted right after the select by select2.
    span_el = select_el.find(:xpath, "following-sibling::span")

    if value == :clear
      span_el.find(".select2-selection__clear").click
    else
      # Several of the elements selected below are inserted at the bottom of the DOM so we can't scope them.
      with_top_level_scope do
        if multiple
          span_el.find(".select2-search__field").click
        else
          execute_script("$('#{css}').select2('open')")
          find(".select2-search--dropdown .select2-search__field").set(value)
        end
        yield
      end
    end
  end

  def pick_datetime(selector, day:, hour:, next_click: "body")
    find("#{selector} .input-group-btn button").click
    within(".bootstrap-datetimepicker-widget") do
      first(".datepicker-days td", text: day, match: :prefer_exact).click
      find("[data-action=togglePicker]").click
      sleep(0.25) # If we don't sleep here, the click doesn't seem to register properly.
      find("[data-action=showHours]").click
      sleep(0.25)
      find(".timepicker-hours td", text: hour.to_s.rjust(2, "0"), match: :prefer_exact).click
    end
    find(next_click).click # Get out of the picker.
  end

  def pick_date(selector, day:, next_click: "body")
    find("#{selector} .input-group-btn button").click
    within(".bootstrap-datetimepicker-widget") do
      first(".datepicker-days td", text: day, match: :prefer_exact).click
    end
    find(next_click).click # Get out of the picker.
  end

  # Min must be a multiple of 5.
  def pick_time(selector, hour:, min:, ampm:, next_click: "body")
    find("#{selector} .input-group-btn button").click
    within(".bootstrap-datetimepicker-widget") do
      find("[data-action=showHours]").click
      sleep(0.25)
      find(".timepicker-hours td", text: hour.to_s.rjust(2, "0")).click
      find("[data-action=showMinutes]").click
      sleep(0.25)
      find(".timepicker-minutes td", text: min.to_s.rjust(2, "0")).click
      sleep(0.25)

      # If the opposite AM/PM button to what we want is visible, we have to click it to
      # change it to what we want.
      begin
        first(".btn-primary", text: ampm == :pm ? "AM" : "PM")&.click
      rescue Capybara::ExpectationNotMet
      end
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

  def have_personal_nav(item)
    have_css(".personal-nav .dropdown-menu a", text: item)
  end

  def have_signed_in_user(user)
    have_css(".personal-nav a", text: user.name)
  end

  def expect_success(pattern = /successfully/)
    expect(page).to have_success_alert(pattern)
  end

  def have_success_alert(pattern = /successfully/)
    have_css("div.alert-success", text: pattern)
  end

  def have_info_alert(pattern)
    have_css("div.alert-info", text: pattern)
  end

  def have_warning_alert(pattern)
    have_css("div.alert-warning", text: pattern)
  end

  def have_danger_alert(pattern)
    have_css("div.alert-danger", text: pattern)
  end

  def have_loading_indicator
    have_css("#glb-load-ind")
  end

  def expect_validation_error(text = nil)
    if text
      expect(page).to have_css("form .error, .form-group .error, .form-group .success", text: text)
    else
      expect(page).to have_css("div.alert-danger", text: /Please review/)
    end
  end
  alias expect_validation_message expect_validation_error

  def expect_image_upload(state:, path: nil)
    within(".dropzone-wrapper") do
      case state
      when :new
        expect(page).to have_css("img[data-dz-thumbnail]", visible: true)
        expect(page.find("img[data-dz-thumbnail]")["src"]).to match(/base64/)
        expect(page).to have_no_css("img.existing", visible: true)
        expect(page).to have_css("a.delete", visible: true)
        expect(page).to have_no_css(".dz-message", visible: true)
      when :existing
        expect(page).not_to have_css("img[data-dz-thumbnail]")
        expect(page).to have_css("img.existing", visible: true)
        expect(page.find("img.existing")["src"]).to match(path)
        expect(page).to have_css("a.delete", visible: true)
        expect(page).to have_no_css(".dz-message", visible: true)
      when :upload_message
        expect(page).to have_no_css("img[data-dz-thumbnail]", visible: true)
        expect(page).to have_no_css("img.existing", visible: true)
        expect(page).to have_css(".dz-message", visible: true)
      end
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
    page.execute_script(<<-JS)
      fakeFileInput = window.$('<input/>').attr(
        {id: 'fakeFileInput', type:'file'}
      ).appendTo('#content');
    JS
    # Attach the file to the fake input selector with Capybara
    attach_file("fakeFileInput", file_path)
    # Trigger the fake drop event
    page.execute_script(<<-JS)
      var e = jQuery.Event('drop', { dataTransfer : { files : [fakeFileInput.get(0).files[0]] } });
      $('.dropzone')[0].dropzone.listeners[0].events.drop(e);
    JS

    # If we don't wait for the upload to finish and another request is processed
    # in the meantime, it can lead to weird failures.
    wait_for_dropzone_upload
  end

  def wait_for_dropzone_upload
    Timeout.timeout(Capybara.default_max_wait_time) do
      loop until page.evaluate_script("!window.uploadView.isUploading()")
    end
  end

  def delete_from_dropzone
    find(:css, ".dropzone-wrapper a.delete").click
    expect_no_image_upload
  end

  def expect_no_image_and_drop_file(filename)
    expect_no_image_upload
    drop_in_dropzone(fixture_file_path(filename))
    expect_image_upload(state: :new)
  end

  # Signs in to the app by filling in the password form instead of using the faster Warden helper login_as.
  # Used for special cases, including when you need to sign out midway through the spec.
  def full_sign_in_as(user, password: FactoryBot::DEFAULT_PASSWORD)
    visit(new_user_session_path)
    fill_in("Email Address", with: user.email)
    fill_in("Password", with: password)
    click_button("Sign In")
  end

  # Only works if you signed in with full_sign_in_as.
  def full_sign_out
    click_on_personal_nav("Sign Out")
    expect(page).to have_content("You are now signed out of Gather.")
  end

  def expect_photo(pattern)
    expect(page.find("img.photo")["src"]).to match(pattern)
  end

  def expect_confirm_on_reload
    accept_confirm { reload_page }
  rescue Capybara::ModalNotFound
    raise("Confirm dialog expected but not shown")
  end

  def expect_no_confirm_on_reload
    accept_confirm { reload_page }
    raise("Confirm dialog not expected but one was shown")
  rescue Capybara::ModalNotFound
  end

  def stub_omniauth(params)
    OmniAuth.config.test_mode = true
    params.each do |key, hash|
      OmniAuth.config.mock_auth[key] = OmniAuth::AuthHash.new(info: hash)
    end
  end

  def inject_session(hash)
    Warden.on_next_request do |proxy|
      hash.each do |key, value|
        proxy.raw_session[key] = value
      end
    end
  end

  def expect_sign_in_with_google_link_and_click
    # Should point to apex domain
    expect(page).to have_css("a[href^='http://#{Settings.url.host}:31337']", text: "Sign in with Google")
    click_link("Sign in with Google")
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
    have_css("#blurb", text: "Life is better together.")
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

  # Checks if the echoed URL (see above) has the given query string key/value pair
  def have_echoed_url_param(param_name, value)
    have_echoed_url(/(&|\?)#{param_name}=#{value}(&|\z)/)
  end

  def set_host(host)
    Capybara.app_host = "http://#{host}"
  end

  def clear_cookie(name)
    browser = Capybara.current_session.driver.browser
    if browser.respond_to?(:manage) # Selenium
      browser.manage.delete_cookie(name)
    elsif browser.respond_to?(:set_cookie) # Rack::Test
      browser.set_cookie(name, nil)
    else
      raise "Don't know how to clear cookie"
    end
  end

  def clear_session_cookie
    clear_cookie("_gather_session")
  end

  def lens_node(param_name)
    first(:css, "[data-param-name=#{param_name}]")
  end

  def select_lens(param_name, label)
    lens_node(param_name).select(label)
  end

  def select2_lens(param_name, label)
    select2(label, from: lens_node(param_name))
  end

  def select_lens_and_wait(param_name, label)
    select_lens(param_name, label)
    value = first(:xpath, "//select[@data-param-name='#{param_name}']/option[.='#{label}']")["value"]
    expect(page).to have_echoed_url_param(param_name, value)
  end

  def select2_lens_and_wait(param_name, label, url_value:)
    select2_lens(param_name, label)
    expect(page).to have_echoed_url_param(param_name, url_value)
  end

  def fill_in_lens(param_name, value)
    page.execute_script("$('.lens-bar.lower [name=#{param_name}]').val('#{value}');")
    page.execute_script("$('.lens-bar.lower').submit()")
  end

  def fill_in_lens_and_wait(param_name, value)
    fill_in_lens(param_name, value)
    expect(page).to have_echoed_url_param(param_name, value)
  end

  def expect_lens_value(param_name, value)
    expect(lens_node(param_name).value).to eq(value)
  end

  def have_select_lens(param_name, **args)
    have_select(param_name.to_s, **args)
  end

  def lens_selected_option(param_name)
    # If there is an explicitly selected option, return that, else return the first one.
    lens_field(param_name).all("option[selected]")[0] || lens_field(param_name).first("option")
  end

  def lens_field(param_name)
    first(lens_selector(param_name))
  end

  def lens_selector(param_name)
    ".#{param_name.to_s.dasherize}-lens"
  end

  def clear_lenses
    find(".lens-bar a.clear").click
  end

  def have_lens_clear_link
    have_css(".lens-bar a.clear")
  end

  def match_and_visit_url(str, regex)
    expect(str).to match(regex)
    visit(str.match(regex)[0].strip)
  end

  def click_delete_link
    find("a .fa-trash").click
  end

  def click_print_button
    first(:css, ".btn-print").click
  end
end
