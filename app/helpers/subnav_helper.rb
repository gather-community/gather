module SubnavHelper
  def subnav_items
    items = case @context[:section]
    when :meals
      policy = policy(Meal)
      [
        {
          name: :meals,
          path: meals_path,
          permitted: policy.index?
        },{
          name: :work,
          path: work_meals_path,
          permitted: policy.work?
        },{
          name: :report,
          path: report_meals_path,
          permitted: policy.report?
        }
      ]
    end
    items.select { |i| i[:permitted] }
    items.each { |i| i[:active] = true if i[:name] == @context[:subsection] }
  end
end
