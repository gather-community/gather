# frozen_string_literal: true

module Work
  # Lens to indicate who is being chosen for (for proxy situations).
  class ChooseeLens < Lens::SelectLens
    param_name :choosee

    def initialize(options:, **params)
      options[:clearable] = false
      options[:global] = true # Global so that it doesn't cause a clear link to show (sort of a hack).
      options[:floating] = true
      super(options: options, **params)
    end

    def render
      h.content_tag(:form, select_tag, class: "form-inline floating-lens hidden-print")
    end

    private

    def chooser
      options[:chooser]
    end

    # Users this user can choose as (must have a nonzero share) for the current period.
    def possible_options
      [chooser].concat(other_household_members, users_with_chooser_as_proxy)
    end

    def name_for_object_option(user)
      I18n.t("work/shift.choosing_as", name: user.decorate.full_name)
    end

    # Other household members with nonzero share for this period.
    def other_household_members
      return [] if period.nil?
      ids = chooser.household.users.pluck(:id) - [chooser.id]
      period.shares.nonzero.where(user_id: ids).includes(:user).map(&:user)
    end

    def users_with_chooser_as_proxy
      User.active.where(job_choosing_proxy_id: chooser.id)
    end

    def period
      set[:period].selection
    end
  end
end
