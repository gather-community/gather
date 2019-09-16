# frozen_string_literal: true

module UsersHelper
  # Use this helper if the current_community *is or may be* different from the target meal's community.
  def user_url(user, *args)
    url_in_community(user.community, user_path(user, *args))
  end

  def phone_link(phone, options = {})
    phone.blank? ? "" : link_to(phone.formatted(options), "tel:#{phone.raw}")
  end
end
