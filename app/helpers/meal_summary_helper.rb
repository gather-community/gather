module MealSummaryHelper
  COST_TABLE_AMOUNTS = [3.5, 4, 4.5, 5, 5.5, 6, 6.5, 7, 8, 9, 10, 11]

  def portion_counts(meal)
    "This meal will require approximately ".html_safe <<
      Meals::Signup::FOOD_TYPES.map do |ft|
        content_tag(:strong) do
          num = meal.portions(ft).ceil
          ft_str = t("signups.food_types.#{ft}").downcase
          "#{num} #{ft_str}"
        end << " portions"
      end.reduce(&sep(" and ")) << ".*"
  end
end
