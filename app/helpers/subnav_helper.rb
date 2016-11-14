module SubnavHelper
  def subnav_items
    items = case @context[:section]
    when :meals
      policy = policy(Meal)
      [
        {
          name: :meals,
          path: meals_path,
          permitted: policy.index?,
          icon: "cutlery"
        },{
          name: :work,
          path: work_meals_path,
          permitted: policy.work?,
          icon: "briefcase"
        },{
          name: :report,
          path: report_meals_path,
          permitted: policy.report?,
          icon: "line-chart"
        }
      ]
    when :people
      [
        {
          name: :directory,
          path: users_path,
          permitted: policy(User).index?,
          icon: "vcard"
        },{
          name: :households,
          path: households_path,
          permitted: policy(Household).index?,
          icon: "home"
        }
      ]
    end
    items.select! { |i| i[:permitted] }
    items.each { |i| i[:active] = true if i[:name] == @context[:subsection] }
  end
end
