# frozen_string_literal: true

# Renders each email in its recipient's locale (see Gather::Locales.for_user) rather than whatever locale was
# active when it was sent. ActiveJob restores the enqueuing request's locale when delivering, so without this
# an email triggered by someone browsing in French would go out to all of its recipients in French.
#
# Mail sent with `.with(recipient: user)` is rendered in that user's locale automatically. A recipient can
# also be several users, who must share a locale: jobs sending one message to a household or a group of
# admins split them by locale first (ApplicationJob#each_recipient_locale_group).
#
# Mailers whose recipient is an action argument instead (AuthMailer's Devise emails, say) wrap the action in
# `in_locale_of`, since the locale has to be set before the subject is looked up.
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

  def recipient_locale
    users = Array.wrap(params&.dig(:recipient)).grep(User)
    locales = users.map { |user| Gather::Locales.for_user(user) }.uniq
    (locales.size == 1) ? locales.first : I18n.default_locale
  end

  # Runs the block in `user`'s locale, or in `locale` if given.
  def in_locale_of(user = nil, locale: nil, &block)
    I18n.with_locale(locale || Gather::Locales.for_user(user), &block)
  end
end
