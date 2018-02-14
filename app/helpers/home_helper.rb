module HomeHelper
  def redirect_to_home_page(current_community)
    return redirect_to users_path if current_community.nil?

    case current_community.settings.default_landing_page
    when "Meals"
      redirect_to meals_path
    when "Directory"
      redirect_to users_path
    when "Reservations"
      redirect_to reservations_path
    when "Wiki"
      redirect_to wiki_pages_path
    else
      redirect_to users_path
    end
  end
end
