# frozen_string_literal: true

module Nav
  # The subnav items under each of CommunityMenu's main items.
  class CommunitySubItems < Menu
    SECTIONS = %i[meals people groups calendars work billing wiki].freeze

    def items_for(main_item)
      SECTIONS.include?(main_item) ? send(main_item) : []
    end

    private

    def meals
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
    end

    def people
      sample_household = Household.new(community: community)
      sample_user = User.new(household: sample_household)
      sample_vehicle = People::Vehicle.new(household: Household.new(community: community))
      sample_memorial = People::Memorial.new(community: community)
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
    end

    def groups
      sample_user = User.new(household: Household.new(community: community))
      sample_group = Groups::Group.new(communities: [community])
      sample_domain = Domain.new(communities: [community])
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
        }, {
          name: :domains,
          parents: :groups,
          path: h.domains_path,
          permitted: h.policy(sample_domain).index?,
          icon: "cloud"
        }
      ]
    end

    def calendars
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
    end

    def work
      sample_period = Work::Period.new(community: community)
      sample_job = Work::Job.new(period: sample_period)
      sample_shift = Work::Shift.new(job: sample_job)
      # Stay within the current period (if any) when switching between work sub-pages.
      # Set by Work::WorkController#load_period.
      period = current_period
      [
        {
          name: :signups,
          parents: :work,
          path: period ? h.work_period_shifts_path(period) : h.work_shifts_path,
          permitted: h.policy(sample_shift).index_wrapper?,
          icon: "check"
        }, {
          name: :report,
          parents: :work,
          path: period ? h.work_period_report_path(period) : h.work_report_path,
          permitted: h.policy(sample_period).report_wrapper?,
          icon: "line-chart"
        }, {
          name: :jobs,
          parents: :work,
          path: period ? h.work_period_jobs_path(period) : h.work_jobs_path,
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
    end

    def billing
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
    end

    def wiki
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
    end
  end
end
