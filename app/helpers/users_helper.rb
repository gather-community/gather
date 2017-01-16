module UsersHelper
  def user_link(user, highlight: nil, show_cmty_if_foreign: false)
    contents = if show_cmty_if_foreign && user.community != current_community
      "#{user.name} (#{user.community_name})"
    else
      user.name
    end
    contents = user.id == highlight.to_i ? content_tag(:mark, contents) : contents
    link = link_to(contents, user_path(user), class: "user-link")
  end

  def phone_link(phone, options = {})
    link_to(phone.formatted(options), "tel:#{phone.raw}")
  end

  def email_link(email)
    link_to(email, "mailto:#{email}")
  end

  def user_photo_if_permitted(user, format)
    image_tag(policy(user).show_photo? ? user.photo.url(format) : "missing/users/#{format}.png",
      class: "photo")
  end
end
