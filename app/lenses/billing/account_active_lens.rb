# frozen_string_literal: true

module Billing
  # Filter for account active only or all
  class AccountActiveLens < Lens::SelectLens
    param_name :active
    i18n_key "simple_form.options.billing_account.active"
    select_prompt :all
    possible_options %i[active_only]
  end
end
