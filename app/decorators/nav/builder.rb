# frozen_string_literal: true

module Nav
  # Defines nav menus and related helper methods.
  class Builder < ApplicationDecorator
    delegate_all

    attr_accessor :context

    def initialize
      self.context = {}
    end

    def main_items(display:)
      sample_household = Household.new(community: community)
      sample_user = User.new(household: sample_household)
      sample_meal = Meals::Meal.new(community: community)
      sample_group = Groups::Group.new(communities: [community])
      sample_period = Work::Period.new(community: community)
      sample_job = Work::Job.new(period: sample_period)
      sample_shift = Work::Shift.new(job: sample_job)
      sample_resource = Reservations::Resource.new(community: community)
      sample_reservation = Reservations::Reservation.new(resource: sample_resource)
      sample_wiki_page = Wiki::Page.new(community: community)
      sample_account = Billing::Account.new(community: community)
      customizer = Utils::Nav::CustomizationParser.new(community&.settings&.main_nav_customizations)

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
        permitted: h.policy(sample_meal).index?,
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
        permitted: h.policy(sample_wiki_page).show?,
        icon: "info-circle"
      )
      items << customizer.filter_item(
        name: :billing,
        path: h.accounts_path,
        permitted: h.policy(sample_account).show?,
        icon: "dollar",
        display: :mobile
      )

      # Add all the new menu items defined as customizations
      items.concat(customizer.extra_items).compact!
      filter_and_set_active_items(items, type: :main, display: display, active: context[:main])
    end

    def sub_items(main_item = nil)
      main_item ||= context[:main]
      items =
        case main_item
        when :meals
          policy = h.policy(Meals::Meal.new(community: community))
          [
            {
              name: :meals,
              parents: :meals,
              path: h.meals_path,
              permitted: policy.index?,
              icon: "cutlery"
            }, {
              name: :jobs,
              parents: :meals,
              path: h.jobs_meals_path,
              permitted: policy.jobs?,
              icon: "briefcase"
            }, {
              name: :report,
              parents: :meals,
              path: h.report_meals_path,
              permitted: policy.report?,
              icon: "line-chart"
            }, {
              name: :formulas,
              parents: :meals,
              path: h.meals_formulas_path,
              permitted: h.policy(Meals::Formula.new(community: community)).index?,
              icon: "calculator"
            }, {
              name: :types,
              parents: :meals,
              path: h.meals_types_path,
              permitted: h.policy(Meals::Type.new(community: community)).index?,
              icon: "cubes"
            }, {
              name: :roles,
              parents: :meals,
              path: h.meals_roles_path,
              permitted: h.policy(Meals::Role.new(community: community)).index?,
              icon: "user-circle-o"
            }
          ]
        when :people
          sample_household = Household.new(community: community)
          sample_user = User.new(household: sample_household)
          sample_vehicle = People::Vehicle.new(household: Household.new(community: community))
          sample_memorial = People::Memorial.new(user: sample_user)
          [
            {
              name: :directory,
              parents: :people,
              path: h.users_path,
              permitted: h.policy(sample_user).index?,
              icon: "address-card"
            }, {
              name: :households,
              parents: :people,
              path: h.households_path,
              permitted: h.policy(sample_household).index?,
              icon: "home"
            }, {
              name: :birthdays,
              parents: :people,
              path: h.people_birthdays_path,
              permitted: h.policy(sample_user).index?,
              icon: "birthday-cake"
            }, {
              name: :vehicles,
              parents: :people,
              path: h.people_vehicles_path,
              permitted: h.policy(sample_vehicle).index?,
              icon: "car"
            }, {
              name: :memorials,
              parents: :people,
              path: h.people_memorials_path,
              permitted: h.policy(sample_memorial).index?,
              icon: "pagelines"
            }, {
              name: :settings,
              parents: :people,
              path: h.edit_people_settings_path,
              permitted: People::SettingsPolicy.new(user, community).edit?,
              icon: "gear"
            }
          ]
        when :groups
          sample_user = User.new(household: sample_household)
          sample_group = Groups::Group.new(communities: [community])
          [
            {
              name: :groups,
              parents: :groups,
              path: h.groups_groups_path,
              permitted: h.policy(sample_group).index?,
              icon: "users"
            }, {
              name: :roles,
              parents: :groups,
              path: h.roles_path,
              permitted: h.policy(sample_user).index?,
              icon: "user-circle-o"
            }
          ]
        when :reservations
          [
            {
              name: :reservations,
              parents: :reservations,
              path: h.reservations_path,
              permitted: h.policy(Reservations::Reservation.new(resource:
                Reservations::Resource.new(community: community))).index?,
              icon: "calendar"
            }, {
              name: :resources,
              parents: :reservations,
              path: h.reservations_resources_path,
              permitted: h.policy(Reservations::Resource.new(community: community)).index?,
              icon: "bed"
            }, {
              name: :protocols,
              parents: :reservations,
              path: h.reservations_protocols_path,
              permitted: h.policy(Reservations::Protocol.new(community: community)).index?,
              icon: "cogs"
            }
          ]
        when :work
          sample_period = Work::Period.new(community: community)
          sample_job = Work::Job.new(period: sample_period)
          sample_shift = Work::Shift.new(job: sample_job)
          [
            {
              name: :signups,
              parents: :work,
              path: h.work_shifts_path,
              permitted: h.policy(sample_shift).index_wrapper?,
              icon: "check"
            }, {
              name: :report,
              parents: :work,
              path: h.work_report_path,
              permitted: h.policy(sample_period).report_wrapper?,
              icon: "line-chart"
            }, {
              name: :jobs,
              parents: :work,
              path: h.work_jobs_path,
              permitted: h.policy(sample_job).index?,
              icon: "wrench"
            }, {
              name: :periods,
              parents: :work,
              path: h.work_periods_path,
              permitted: h.policy(sample_period).index?,
              icon: "folder-open"
            }
          ]
        when :billing
          sample_account = Billing::Account.new(community: community)
          [
            {
              name: :accounts,
              parents: :billing,
              path: h.accounts_path,
              permitted: h.policy(sample_account).index?,
              icon: "book"
            }, {
              name: :templates,
              parents: :billing,
              path: h.billing_templates_path,
              permitted: h.policy(sample_account).index?,
              icon: "copy"
            }
          ]
        else
          []
        end
      filter_and_set_active_items(items, type: :sub, active: context[:sub_item])
    end

    # This method has no arguments because it's only called once. It's not used to populate
    # the hamburger menu.
    def sub_sub_items
      return @sub_sub_items if defined?(@sub_sub_items)
      sample_member_type = People::MemberType.new(community: community)
      items =
        case [context[:main], context[:sub_item]]
        when %i[people settings]
          [{
            name: :general,
            parents: %i[people settings],
            path: h.edit_people_settings_path,
            permitted: People::SettingsPolicy.new(user, community).edit?,
          },{
            name: :member_types,
            parents: %i[people settings],
            path: h.people_member_types_path,
            permitted: h.policy(sample_member_type).index?
          }]
        end
      @sub_sub_items = filter_and_set_active_items(items, type: :sub_sub, active: context[:sub_sub_item])
    end

    def personal_items
      sample_export = Calendars::Exports::Export.new(user: user)
      items =
        [
          {
            name: :profile,
            path: h.user_url(user),
            permitted: h.policy(user).show?,
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
            permitted: Calendars::ExportPolicy.new(user, sample_export).index?,
            icon: "calendar"
          }, {
            name: :change_passwd,
            path: h.people_password_change_path(user),
            permitted: UserPolicy.new(user, user).update?,
            icon: "asterisk"
          }, {
            name: :sign_out,
            path: h.destroy_user_session_path,
            permitted: true,
            icon: "sign-out",
            method: :delete
          }
        ]
      filter_and_set_active_items(items, type: :personal)
    end

    def link(item, tab: false, icon: true)
      name = if item[:name].is_a?(String)
               item[:name]
             else
               i18n_key_parts = ["nav_links", item[:type]]
               i18n_key_parts.concat(Array.wrap(item[:parents]))
               i18n_key_parts << (item[:i18n_key] || item[:name])
               name = t(i18n_key_parts.join("."))
             end
      params = {}
      params[:method] = item[:method]
      params[:role] = "tab" if tab
      params[:"aria-controls"] = name if tab
      icon_tag = icon && item[:icon] ? h.icon_tag(item[:icon]) << " " : h.safe_str
      h.link_to(icon_tag << " #{name}", item[:path], params)
    end

    def lens_path_if_present(controller, index_path: nil)
      storage = Lens::Storage.new(session: h.session, community_id: community.id,
                                  controller_path: controller, action_name: "index")
      Lens::PathSaver.new(storage: storage).read || index_path || h.send("#{controller.tr('/', '_')}_path")
    end

    protected

    def filter_and_set_active_items(items, type:, display: nil, active: nil)
      return [] if items.blank?
      items.select! { |i| i[:permitted] && display.nil? || i[:display].nil? || i[:display] == display }
      items.each do |i|
        i[:type] = type
        i[:active] = true if active && i[:name] == active
      end
      items
    end

    private

    def user
      h.current_user
    end

    def community
      h.current_community
    end
  end
end
