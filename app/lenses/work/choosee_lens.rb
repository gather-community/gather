# frozen_string_literal: true

module Work
  # Lens to indicate who is being chosen for (for proxy situations).
  class ChooseeLens < ApplicationLens
    param_name :choosee

    def initialize(context:, options:, **params)
      options[:required] = true
      options[:global] = true
      options[:default] = options[:chooser].id
      options[:floating] = true
      super(options: options, context: context, **params)
      prohibit_values_not_in_candidate_list
    end

    def render
      h.content_tag(:form, class: "form-inline floating-lens hidden-print") do
        h.select_tag(param_name, option_tags,
          class: "form-control",
          onchange: "this.form.submit();",
          "data-param-name": param_name)
      end
    end

    def choosee
      User.find_by(id: value)
    end

    private

    def chooser
      options[:chooser]
    end

    def option_tags
      h.options_for_select(candidates.map { |c| [option_name_for(c), c.id] }, value)
    end

    def option_name_for(user)
      I18n.t("work/shift.choosing_as", name: user.decorate.full_name)
    end

    # Users this user can choose as (must have a nonzero share) for the current period.
    def candidates
      @candidates ||= [chooser] + other_household_members + users_with_chooser_as_proxy
    end

    # Other household members with nonzero share for this period.
    def other_household_members
      ids = chooser.household.users.pluck(:id) - [chooser.id]
      period.shares.nonzero.where(user_id: ids).includes(:user).map(&:user)
    end

    def users_with_chooser_as_proxy
      User.active.where(job_choosing_proxy_id: chooser.id)
    end

    def period
      set[:period].object
    end

    # This could one day be generic select lens functionality.
    def prohibit_values_not_in_candidate_list
      self.value = chooser.id.to_s unless candidates.any? { |c| c.id.to_s == value }
    end
  end
end
