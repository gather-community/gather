# frozen_string_literal: true

module People
  module Users
    # Overriding the i18n_options method in the Devise FailureApp so that we can have control
    # over how the authentication_keys parameter to the messages under devise.failure is translated.
    # By default the `human_attribute_name` of the attribute is used, but those are typically capitalized,
    # while the messages call for a lowercase value.
    # This custom failure app must be activated in the config/initializers/devise.rb file.
    class CustomDeviseFailureApp < Devise::FailureApp
      def i18n_options(options)
        options.merge(authentication_keys: I18n.t("devise.authentication_keys.email"))
      end
    end
  end
end
