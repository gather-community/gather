# frozen_string_literal: true

# Renders each email in its recipient's locale rather than whatever locale was active when it was sent.
# This matters because ActiveJob restores the enqueuing request's locale when delivering, so without this an
# email triggered by someone browsing in French would go out to all of its recipients in French.
#
# Every mailer must include this; spec/mailers/recipient_locale_spec.rb checks that they do.
module RecipientLocale
  extend ActiveSupport::Concern

  included do
    around_action :with_recipient_locale
  end

  private

  def with_recipient_locale(&action)
    I18n.with_locale(recipient_locale, &action)
  end

  # Users can't choose a language for email yet, so everyone gets the default locale.
  def recipient_locale
    I18n.default_locale
  end
end
