module NavHelper
  def nav_items
    items = [
      {
        name: :people,
        path: lens_path_if_present("users"),
        permitted: policy(User).index?
      },{
        name: :meals,
        path: lens_path_if_present("meals"),
        permitted: policy(Meal).index?
      },{
        name: :reservations,
        path: lens_path_if_present("reservations"),
        permitted: policy(Reservation::Reservation).index?
      },{
        name: :accounts,
        path: lens_path_if_present("accounts"),
        permitted: policy(Billing::Account).index?
      }
    ]
    filter_and_set_active_nav_items(items, @context[:section])
  end

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
    filter_and_set_active_nav_items(items, @context[:subsection])
  end

  def filter_and_set_active_nav_items(items, active)
    items.select! { |i| i[:permitted] }
    items.each { |i| i[:active] = true if i[:name] == active }
  end

  def lens_path_if_present(controller)
    Lens.path_for(context: self, controller: controller, action: "index") || send("#{controller}_path")
  end
end
