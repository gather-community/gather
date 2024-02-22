# frozen_string_literal: true

# Miscellaneous things that need to run after each spec.
RSpec.configure do |config|
  config.after(type: :system) do
    # Clear these again after example so we don't leave junk in there after the suite is run.
    clear_downloads
  end

  # Print browser logs to console if they are non-empty.
  # You MUST use console.warn or console.error for this to work.
  # This produces Selenium::WebDriver::Error::WebDriverError "unknown command" on Travis for some reason.
  unless ENV["CI"]
    config.after(:each, type: :system, js: true) do
      # logs = page.driver.browser.logs.get(:browser).join("\n")
      # unless logs.strip.empty?
      #   puts("------------ BROWSER LOGS -------------")
      #   puts(logs)
      #   puts("---------------------------------------")
      # end
    end
  end
end
