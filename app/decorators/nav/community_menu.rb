# frozen_string_literal: true

module Nav
  # Nav for pages within a community.
  class CommunityMenu < Menu
    def main_items
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
      items.concat(customizer.extra_items).compact
    end

    def sub_items(main_item)
      CommunitySubItems.new(builder).items_for(main_item)
    end

    def sub_sub_items
      sample_member_type = People::MemberType.new(community: community)
      if context[0..1] == %i[people settings]
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
    end

    def personal_items
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
          path: h.mine_accounts_path,
          permitted: h.policy(Billing::Account.new).mine?,
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
          name: :notifications,
          parents: [:personal],
          path: h.notification_preferences_path,
          permitted: UserPolicy.new(user, user).update_notification_prefs?,
          icon: "bell"
        },
        sign_out_item
      ]
    end
  end
end
