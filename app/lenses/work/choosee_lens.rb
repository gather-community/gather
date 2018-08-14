# frozen_string_literal: true

module Work
  # Lens to indicate who is being chosen for (for proxy situations).
  class ChooseeLens < ApplicationLens
    param_name :choosee

    def render
      h.select_tag(param_name, option_tags,
        prompt: option_name_for(options[:chooser]),
        class: "form-control",
        onchange: "this.form.submit();",
        "data-param-name": param_name)
    end

    private

    def option_tags
      h.options_for_select(candidates.map { |c| [option_name_for(c), c.id] }, value)
    end

    def option_name_for(user)
      I18n.t("work/shift.choosing_as", name: user.decorate.full_name)
    end

    # Users this user can choose as (must have a nonzero share) for the current period.
    def candidates
      period.shares.nonzero.where(user_id: candidate_ids).includes(:user).map(&:user)
    end

    def candidate_ids
      options[:chooser].household.users.pluck(:id) - [options[:chooser].id]
    end

    def period
      set[:period].object
    end
  end
end
