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
      sample_calendar = Calendars::Calendar.new(community: community)
      sample_event = Calendars::Event.new(calendar: sample_calendar)
      sample_wiki_page = Wiki::Page.new(community: community)
      sample_account = Billing::Account.new(community: community)
      customizer = Utils::Nav::CustomizationParser.new(community&.settings&.main_nav_customizations)

      items = []

      # Run each hard-coded menu item through the customization filter and then add it to the list.
      items << customizer.filter_item(
        name: :people,
        path: h.users_path,
        permitted: h.policy(sample_user).index?,
        icon: "address-book"
      )
      items << customizer.filter_item(
        name: :groups,
        path: h.groups_groups_path,
        permitted: h.policy(sample_group).index?,
        icon: "users"
      )
      items << customizer.filter_item(
        name: :meals,
        path: h.meals_path,
        permitted: h.policy(sample_meal).index?,
        icon: "cutlery"
      )
      items << customizer.filter_item(
        name: :work,
        path: h.work_shifts_path,
        permitted: h.policy(sample_shift).index_wrapper?,
        icon: "wrench"
      )
      items << customizer.filter_item(
        name: :calendars,
        path: h.calendars_events_path,
        permitted: h.policy(sample_event).index?,
        icon: "calendar"
      )
      items << customizer.filter_item(
        name: :wiki,
        path: h.wiki_pages_path,
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
      filter_and_set_active_items(items, display: display, active: context[0])
    end

    def sub_items(main_item = nil)
      main_item ||= context[0]
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
              icon: "user-circle"
            }, {
              name: :settings,
              parents: :meals,
              path: h.edit_meals_settings_path,
              permitted: SettingsPolicy.new(user, community).edit?,
              icon: "gear"
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
              icon: {name: "pagelines", style: :brands}
            }, {
              name: :settings,
              parents: :people,
              path: h.edit_people_settings_path,
              permitted: SettingsPolicy.new(user, community).edit?,
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
              icon: "user-circle"
            }
          ]
        when :calendars
          [
            {
              name: :events,
              parents: :calendars,
              path: h.calendars_events_path,
              permitted: h.policy(Calendars::Event.new(calendar:
                Calendars::Calendar.new(community: community))).index?,
              icon: "ticket"
            }, {
              name: :calendars,
              parents: :calendars,
              path: h.calendars_path,
              permitted: h.policy(Calendars::Calendar.new(community: community)).index?,
              icon: "calendar"
            }, {
              name: :protocols,
              parents: :calendars,
              path: h.calendars_protocols_path,
              permitted: h.policy(Calendars::Protocol.new(community: community)).index?,
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
            }, {
              name: :settings,
              parents: :work,
              path: h.edit_work_settings_path,
              permitted: SettingsPolicy.new(user, community).edit?,
              icon: "gear"
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
        when :wiki
          sample_wiki_page = Wiki::Page.new(community: community)
          [
            {
              name: :wiki,
              parents: :wiki,
              path: h.wiki_pages_path,
              permitted: h.policy(sample_wiki_page).show?,
              icon: "info-circle"
            },
            {
              name: :gdrive,
              parents: :wiki,
              path: h.gdrive_home_path,
              permitted: GDrive::BrowsePolicy.new(user, :folder).index?,
              icon: {name: "google", style: :brands}
            }
          ]
        else
          []
        end
      filter_and_set_active_items(items, active: context[1])
    end

    # This method has no arguments because it's only called once. It's not used to populate
    # the hamburger menu.
    def sub_sub_items
      return @sub_sub_items if defined?(@sub_sub_items)
      sample_member_type = People::MemberType.new(community: community)
      depth = 0
      items =
        if context[0..1] == %i[people settings]
          depth = 2
          [{
            name: :general,
            parents: %i[people settings],
            path: h.edit_people_settings_path,
            permitted: SettingsPolicy.new(user, community).edit?
          }, {
            name: :member_types,
            parents: %i[people settings],
            path: h.people_member_types_path,
            permitted: h.policy(sample_member_type).index?
          }]
        elsif context[0..1] == %i[meals settings]
          depth = 2
          [{
            name: :general,
            parents: %i[meals settings],
            path: h.edit_meals_settings_path,
            permitted: SettingsPolicy.new(user, community).edit?
          }, {
            name: :restrictions,
            parents: %i[meals settings],
            path: h.edit_meals_restrictions_path,
            permitted: h.policy(sample_member_type).index?
          }]
        elsif context[0..3] == %i[wiki gdrive migration dashboard]
          depth = 4
          [{
            name: :status,
            parents: %i[wiki gdrive migration dashboard],
            path: h.gdrive_migration_dashboard_status_path,
            permitted: GDrive::SetupPolicy.new(user, community).setup?
          }, {
            name: :owners,
            parents: %i[wiki gdrive migration dashboard],
            path: h.gdrive_migration_dashboard_owners_path,
            permitted: GDrive::SetupPolicy.new(user, community).setup?
          }, {
            name: :files,
            parents: %i[wiki gdrive migration dashboard],
            path: h.gdrive_migration_dashboard_files_path,
            permitted: GDrive::SetupPolicy.new(user, community).setup?
          }, {
            name: :logs,
            parents: %i[wiki gdrive migration dashboard],
            path: h.gdrive_migration_dashboard_logs_path,
            permitted: GDrive::SetupPolicy.new(user, community).setup?
          }]
        end
      @sub_sub_items = filter_and_set_active_items(items, active: context[depth])
    end

    def personal_items
      items =
        [
          {
            name: :profile,
            parents: [:personal],
            path: h.user_url(user),
            permitted: h.policy(user).show?,
            icon: "vcard"
          }, {
            name: :accounts,
            parents: [:personal],
            path: h.yours_accounts_path,
            permitted: h.policy(Billing::Account.new).yours?,
            icon: "coins",
            i18n_key: multi_community? ? :accounts : :account
          }, {
            name: :calendars,
            parents: [:personal],
            path: h.calendars_legacy_exports_path,
            permitted: user.settings["show_legacy_calendar_export_links"],
            icon: "calendar"
          }, {
            name: :change_passwd,
            parents: [:personal],
            path: h.people_password_change_path(user),
            permitted: UserPolicy.new(user, user).update?,
            icon: "asterisk"
          }, {
            name: :sign_out,
            parents: [:personal],
            path: h.destroy_user_session_path,
            permitted: true,
            icon: "sign-out",
            method: :delete
          }
        ]
      filter_and_set_active_items(items)
    end

    def link(item, tab: false, icon: true)
      name = if item[:name].is_a?(String)
        item[:name]
      else
        i18n_key_parts = ["nav_links"]
        i18n_key_parts.concat(Array.wrap(item[:parents]))
        i18n_key_parts << (item[:i18n_key] || item[:name])
        i18n_key = i18n_key_parts.join(".")
        name = t("#{i18n_key}._self", default: t(i18n_key))
      end
      params = {}
      params[:method] = item[:method]
      params[:role] = "tab" if tab
      params[:"aria-controls"] = name if tab
      icon_tag = if icon && item[:icon]
        icon_name = item[:icon].is_a?(Hash) ? item[:icon][:name] : item[:icon]
        icon_style = item[:icon].is_a?(Hash) ? item[:icon][:style] : nil
        h.icon_tag(icon_name, style: icon_style) << " "
      else
        h.safe_str
      end

      # We have to add the full host, port, and protocol if it's not given since some pages
      # are under the apex gather domain with community specified through query string but we want the
      # nav links to go back to the subdomain.
      url = /\Ahttps?:\/\//.match?(item[:path]) ? item[:path] : h.url_in_community(community, item[:path])

      h.link_to(icon_tag << " #{name}", url, params)
    end

    protected

    def filter_and_set_active_items(items, display: nil, active: nil)
      return [] if items.blank?
      items.select! { |i| i[:permitted] && (display.nil? || i[:display].nil? || i[:display] == display) }
      items.each do |i|
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
