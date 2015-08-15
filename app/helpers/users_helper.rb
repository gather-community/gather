module UsersHelper
  def user_link(user, user_id_to_highlight)
    contents = user.id == user_id_to_highlight.to_i ? content_tag(:mark, user.name) : user.name
    link = link_to(contents, user_path(user), class: "user-link")
  end
end
