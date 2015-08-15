module MealsHelper
  def signed_up_class(meal)
    meal.signup_for(current_user).present? ? "signed-up" : ""
  end
end
