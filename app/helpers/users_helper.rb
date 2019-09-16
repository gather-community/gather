# frozen_string_literal: true

module UsersHelper
  # Use this helper if the current_community *is or may be* different from the target meal's community.
  def user_url(user, *args)
    url_in_community(user.community, user_path(user, *args))
  end

  def user_link(user, highlight: nil, show_cmty_if_foreign: false)
    contents = if show_cmty_if_foreign && user.community != current_community
                 "#{user.name} (#{user.community_name})"
               else
                 user.name
               end
    contents = user.id == highlight.to_i ? content_tag(:mark, contents) : contents
    link_to(contents, user_url(user), class: "user-link")
  end

  def phone_link(phone, options = {})
    phone.blank? ? "" : link_to(phone.formatted(options), "tel:#{phone.raw}")
  end
end
