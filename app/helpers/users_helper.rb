# frozen_string_literal: true

module UsersHelper
  # Use this helper if the current_community *is or may be* different from the target meal's community.
  def user_url(user, *)
    url_in_community(user.community, user_path(user, *))
  end

  def phone_link(phone, **)
    phone.blank? ? "" : link_to(phone.formatted(**), "tel:#{phone.raw}")
  end
end
