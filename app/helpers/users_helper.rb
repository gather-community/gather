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

  def user_phones(user)
    user.phones.map{ |p| content_tag(:span, p) }.reduce(:<<)
  end
end
