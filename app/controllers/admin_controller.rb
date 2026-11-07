# frozen_string_literal: true

# Base controller for operator (super admin) pages. These live on the apex domain and span all
# clusters; on the apex domain, tenant scoping is off, so queries cover every cluster.
# They get their own nav, header and footer (see admin_mode?).
#
# They aren't translated: they always render in English, and their strings exist only in the English
# locale files (see ignore_missing in config/i18n-tasks.yml).
class AdminController < ApplicationController
  # Runs inside ApplicationControllable::Locale's around_action, so it has the last word.
  around_action ->(_controller, action) { I18n.with_locale(:en, &action) }

  protected

  def apex_domain_only
    true
  end

  def admin_mode?
    true
  end
end
