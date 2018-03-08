# frozen_string_literal: true

# Defines nav menus and related helper methods.
module NavHelper
  def nav_items
    items = [
      {
        name: :people,
        path: lens_path_if_present("users"),
        permitted: policy(User).index?,
        icon: "users"
      }, {
        name: :meals,
        path: lens_path_if_present("meals"),
        permitted: policy(Meal.new(community: current_community)).index?,
        icon: "cutlery"
      }, {
        name: :reservations,
        path: lens_path_if_present("reservations"),
        permitted: policy(Reservations::Reservation).index?,
        icon: "book"
      }, {
        name: :work,
        path: work_shifts_path,
        permitted: policy(Work::Period.new(community: current_community)).index?,
        icon: "info-circle"
      }, {
        name: :wiki,
        path: "/wiki",
        permitted: policy(Wiki::Page.new(community: current_community)).show?,
        icon: "info-circle"
      }
    ]
    filter_and_set_active_nav_items(items, type: :main, active: @context[:section])
  end

  def subnav_items(main = nil)
    main ||= @context[:section]
    items =
      case main
      when :meals
        policy = policy(Meal.new(community: current_community))
        [
          {
            name: :meals,
            parent: :meals,
            path: meals_path,
            permitted: policy.index?,
            icon: "cutlery"
          }, {
            name: :jobs,
            parent: :meals,
            path: jobs_meals_path,
            permitted: policy.jobs?,
            icon: "briefcase"
          }, {
            name: :reports,
            parent: :meals,
            path: reports_meals_path,
            permitted: policy.reports?,
            icon: "line-chart"
          }, {
            name: :formulas,
            parent: :meals,
            path: meals_formulas_path,
            permitted: policy(Meals::Formula.new(community: current_community)).index?,
            icon: "calculator"
          }
        ]
      when :people
        [
          {
            name: :directory,
            parent: :people,
            path: users_path,
            permitted: policy(User).index?,
            icon: "address-book"
          }, {
            name: :households,
            parent: :people,
            path: households_path,
            permitted: policy(Household.new(community: current_community)).index?,
            icon: "home"
          }
        ]
      when :reservations
        [
          {
            name: :reservations,
            parent: :reservations,
            path: reservations_path,
            permitted: policy(Reservations::Reservation).index?,
            icon: "calendar"
          }, {
            name: :resources,
            parent: :reservations,
            path: reservations_resources_path,
            permitted: policy(Reservations::Resource.new(community: current_community)).index?,
            icon: "bed"
          }
        ]
      when :work
        sample_period = Work::Period.new(community: current_community)
        sample_job = Work::Job.new(period: sample_period)
        sample_shift = Work::Shift.new(job: sample_job)
        [
          {
            name: :signups,
            parent: :work,
            path: work_shifts_path,
            permitted: policy(Work::Assignment.new(shift: sample_shift)).index?,
            icon: "check"
          }, {
            name: :jobs,
            parent: :work,
            path: work_jobs_path,
            permitted: policy(Work::Job.new(period: sample_period)).index?,
            icon: "wrench"
          }, {
            name: :periods,
            parent: :work,
            path: work_periods_path,
            permitted: policy(sample_period).index?,
            icon: "hourglass-half"
          }
        ]
      else
        []
      end
    filter_and_set_active_nav_items(items, type: :sub, active: @context[:subsection])
  end

  def personal_nav_items
    items =
      [
        {
          name: :profile,
          path: user_path(current_user),
          permitted: policy(current_user).show?,
          icon: "vcard"
        }, {
          name: :accounts,
          path: accounts_household_path(current_user.household),
          permitted: policy(current_user.household).accounts?,
          icon: "money",
          i18n_key: multi_community? ? :accounts : :account
        }, {
          name: :calendars,
          path: calendar_exports_path,
          permitted: policy(CalendarExport).index?,
          icon: "calendar"
        }, {
          name: :sign_out,
          path: destroy_user_session_path,
          permitted: true,
          icon: "sign-out",
          method: :delete
        }
      ]
    filter_and_set_active_nav_items(items, type: :personal)
  end

  def footer_items
    items =
      case @context[:section]
      when :wiki
        [
          {
            name: :all,
            parent: :wiki,
            path: all_wiki_pages_path,
            permitted: policy(Wiki::Page.new(community: current_community)).all?
          }, {
            name: :new,
            parent: :wiki,
            path: new_wiki_page_path,
            permitted: policy(Wiki::Page.new(community: current_community)).create?
          }
        ]
      else
        []
      end
    filter_and_set_active_nav_items(items, type: :footer)
  end

  def filter_and_set_active_nav_items(items, type:, active: nil)
    items.select! { |i| i[:permitted] }
    items.each do |i|
      i[:type] = type
      i[:active] = true if active && i[:name] == active
    end
    items
  end

  def nav_link(item, tab: false)
    params = {}
    params[:method] = item[:method]
    params[:role] = "tab" if tab
    params[:"aria-controls"] = item[:name] if tab

    i18n_sub_key = item[:parent] ? "#{item[:parent]}." : ""
    name = t("nav_links.#{item[:type]}.#{i18n_sub_key}#{item[:i18n_key] || item[:name]}")

    icon = item[:icon] ? icon_tag(item[:icon]) << " " : ""

    link_to(icon << " #{name}", item[:path], params)
  end

  def lens_path_if_present(controller)
    Lens::Set.path_for(context: self, controller: controller, action: "index") || send("#{controller}_path")
  end
end
