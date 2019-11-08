# frozen_string_literal: true

# Miscellaneous things that need to run after each spec.
RSpec.configure do |config|
  config.after(type: :system) do
    # Clear these again after example so we don't leave junk in there after the suite is run.
    clear_downloads
  end
end
