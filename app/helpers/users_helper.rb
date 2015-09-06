module UsersHelper
  def user_link(user, user_id_to_highlight = nil)
    contents = user.id == user_id_to_highlight.to_i ? content_tag(:mark, user.name) : user.name
    link = link_to(contents, user_path(user), class: "user-link")
  end

  def user_phones(user)
    user.phones.map{ |p| content_tag(:span, p) }.reduce(:<<)
  end
end
