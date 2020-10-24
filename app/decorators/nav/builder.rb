# frozen_string_literal: true

module Nav
  # Defines nav menus and related helper methods.
  class Builder < ApplicationDecorator
    delegate_all

    attr_accessor :context

    def initialize
      self.context = {}
    end

    def main_items
      sample_household = Household.new(community: h.current_community)
      sample_user = User.new(household: sample_household)
      sample_group = Groups::Group.new(communities: [h.current_community])
      sample_period = Work::Period.new(community: h.current_community)
      sample_job = Work::Job.new(period: sample_period)
      sample_shift = Work::Shift.new(job: sample_job)
      sample_resource = Reservations::Resource.new(community: h.current_community)
      sample_reservation = Reservations::Reservation.new(resource: sample_resource)
      customizer = Utils::Nav::CustomizationParser.new(h.current_community&.settings&.main_nav_customizations)

      items = []

      # Run each hard-coded menu item through the customization filter and then add it to the list.
      items << customizer.filter_item(
        name: :people,
        path: lens_path_if_present("users"),
        permitted: h.policy(sample_user).index?,
        icon: "address-book"
      )
      items << customizer.filter_item(
        name: :groups,
        path: lens_path_if_present("groups/groups"),
        permitted: h.policy(sample_group).index?,
        icon: "users"
      )
      items << customizer.filter_item(
        name: :meals,
        path: lens_path_if_present("meals/meals", index_path: h.meals_path),
        permitted: h.policy(Meals::Meal.new(community: h.current_community)).index?,
        icon: "cutlery"
      )
      items << customizer.filter_item(
        name: :work,
        path: lens_path_if_present("work/shifts", index_path: h.work_shifts_path),
        permitted: h.policy(sample_shift).index_wrapper?,
        icon: "wrench"
      )
      items << customizer.filter_item(
        name: :reservations,
        path: lens_path_if_present("reservations"),
        permitted: h.policy(sample_reservation).index?,
        icon: "book"
      )
      items << customizer.filter_item(
        name: :wiki,
        path: "/wiki",
        permitted: h.policy(Wiki::Page.new(community: h.current_community)).show?,
        icon: "info-circle"
      )

      # Add all the new menu items defined as customizations
      items.concat(customizer.extra_items).compact!
      filter_and_set_active_main_items(items, type: :main, active: context[:section])
    end

    def sub_items(main = nil)
      main ||= context[:section]
      items =
        case main
        when :meals
          policy = h.policy(Meals::Meal.new(community: h.current_community))
          [
            {
              name: :meals,
              parent: :meals,
              path: h.meals_path,
              permitted: policy.index?,
              icon: "cutlery"
            }, {
              name: :jobs,
              parent: :meals,
              path: h.jobs_meals_path,
              permitted: policy.jobs?,
              icon: "briefcase"
            }, {
              name: :report,
              parent: :meals,
              path: h.report_meals_path,
              permitted: policy.report?,
              icon: "line-chart"
            }, {
              name: :formulas,
              parent: :meals,
              path: h.meals_formulas_path,
              permitted: h.policy(Meals::Formula.new(community: h.current_community)).index?,
              icon: "calculator"
            }, {
              name: :types,
              parent: :meals,
              path: h.meals_types_path,
              permitted: h.policy(Meals::Type.new(community: h.current_community)).index?,
              icon: "cubes"
            }, {
              name: :roles,
              parent: :meals,
              path: h.meals_roles_path,
              permitted: h.policy(Meals::Role.new(community: h.current_community)).index?,
              icon: "user-circle-o"
            }
          ]
        when :people
          sample_household = Household.new(community: h.current_community)
          sample_user = User.new(household: sample_household)
          sample_vehicle = People::Vehicle.new(household: Household.new(community: h.current_community))
          sample_memorial = People::Memorial.new(user: sample_user)
          [
            {
              name: :directory,
              parent: :people,
              path: h.users_path,
              permitted: h.policy(sample_user).index?,
              icon: "address-card"
            }, {
              name: :households,
              parent: :people,
              path: h.households_path,
              permitted: h.policy(sample_household).index?,
              icon: "home"
            }, {
              name: :birthdays,
              parent: :people,
              path: h.people_birthdays_path,
              permitted: h.policy(sample_user).index?,
              icon: "birthday-cake"
            }, {
              name: :vehicles,
              parent: :people,
              path: h.people_vehicles_path,
              permitted: h.policy(sample_vehicle).index?,
              icon: "car"
            }, {
              name: :memorials,
              parent: :people,
              path: h.people_memorials_path,
              permitted: h.policy(sample_memorial).index?,
              icon: "pagelines"
            }, {
              name: :settings,
              parent: :people,
              path: h.edit_people_settings_path,
              permitted: People::SettingsPolicy.new(h.current_user, h.current_community).edit?,
              icon: "gear"
            }
          ]
        when :groups
          sample_user = User.new(household: sample_household)
          sample_group = Groups::Group.new(communities: [h.current_community])
          [
            {
              name: :groups,
              parent: :groups,
              path: h.groups_groups_path,
              permitted: h.policy(sample_group).index?,
              icon: "users"
            }, {
              name: :roles,
              parent: :groups,
              path: h.roles_path,
              permitted: h.policy(sample_user).index?,
              icon: "user-circle-o"
            }
          ]
        when :reservations
          [
            {
              name: :reservations,
              parent: :reservations,
              path: h.reservations_path,
              permitted: h.policy(Reservations::Reservation.new(resource:
                Reservations::Resource.new(community: h.current_community))).index?,
              icon: "calendar"
            }, {
              name: :resources,
              parent: :reservations,
              path: h.reservations_resources_path,
              permitted: h.policy(Reservations::Resource.new(community: h.current_community)).index?,
              icon: "bed"
            }, {
              name: :protocols,
              parent: :reservations,
              path: h.reservations_protocols_path,
              permitted: h.policy(Reservations::Protocol.new(community: h.current_community)).index?,
              icon: "cogs"
            }
          ]
        when :work
          sample_period = Work::Period.new(community: h.current_community)
          sample_job = Work::Job.new(period: sample_period)
          sample_shift = Work::Shift.new(job: sample_job)
          [
            {
              name: :signups,
              parent: :work,
              path: h.work_shifts_path,
              permitted: h.policy(sample_shift).index_wrapper?,
              icon: "check"
            }, {
              name: :report,
              parent: :work,
              path: h.work_report_path,
              permitted: h.policy(sample_period).report_wrapper?,
              icon: "line-chart"
            }, {
              name: :jobs,
              parent: :work,
              path: h.work_jobs_path,
              permitted: h.policy(sample_job).index?,
              icon: "wrench"
            }, {
              name: :periods,
              parent: :work,
              path: h.work_periods_path,
              permitted: h.policy(sample_period).index?,
              icon: "folder-open"
            }
          ]
        else
          []
        end
      filter_and_set_active_main_items(items, type: :sub, active: context[:subsection])
    end

    def personal_items
      sample_export = Calendars::Exports::Export.new(user: h.current_user)
      items =
        [
          {
            name: :profile,
            path: h.user_url(h.current_user),
            permitted: h.policy(h.current_user).show?,
            icon: "vcard"
          }, {
            name: :accounts,
            path: h.yours_accounts_path,
            permitted: h.policy(Billing::Account.new).yours?,
            icon: "money",
            i18n_key: multi_community? ? :accounts : :account
          }, {
            name: :calendars,
            path: h.calendar_exports_path,
            permitted: Calendars::ExportPolicy.new(h.current_user, sample_export).index?,
            icon: "calendar"
          }, {
            name: :change_passwd,
            path: h.people_password_change_path(h.current_user),
            permitted: UserPolicy.new(h.current_user, h.current_user).update?,
            icon: "asterisk"
          }, {
            name: :sign_out,
            path: h.destroy_user_session_path,
            permitted: true,
            icon: "sign-out",
            method: :delete
          }
        ]
      filter_and_set_active_main_items(items, type: :personal)
    end

    def link(item, tab: false, icon: true)
      i18n_sub_key = item[:parent] ? "#{item[:parent]}." : ""
      name = if item[:name].is_a?(Symbol)
               t("nav_links.#{item[:type]}.#{i18n_sub_key}#{item[:i18n_key] || item[:name]}")
             else
               item[:name]
             end

      params = {}
      params[:method] = item[:method]
      params[:role] = "tab" if tab
      params[:"aria-controls"] = name if tab
      icon_tag = icon && item[:icon] ? h.icon_tag(item[:icon]) << " " : h.safe_str
      h.link_to(icon_tag << " #{name}", item[:path], params)
    end

    def lens_path_if_present(controller, index_path: nil)
      storage = Lens::Storage.new(session: h.session, community_id: h.current_community.id,
                                  controller_path: controller, action_name: "index")
      Lens::PathSaver.new(storage: storage).read || index_path || h.send("#{controller.tr('/', '_')}_path")
    end

    protected

    def filter_and_set_active_main_items(items, type:, active: nil)
      items.select! { |i| i[:permitted] }
      items.each do |i|
        i[:type] = type
        i[:active] = true if active && i[:name] == active
      end
      items
    end
  end
end
