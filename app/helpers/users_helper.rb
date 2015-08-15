module UsersHelper
  def user_link(user)
    link_to(user.name, user_path(user), class: "user-link")
  end
end
