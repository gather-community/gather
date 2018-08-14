# frozen_string_literal: true

module Work
  # Lens to indicate who is being chosen for (for proxy situations).
  class ChooseeLens < ApplicationLens
    param_name :choosee

    def initialize(context:, options:, **params)
      options[:required] = true
      options[:global] = true
      options[:default] = options[:chooser]
      options[:floating] = true
      super(options: options, context: context, **params)
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

    def option_tags
      h.options_for_select(candidates.map { |c| [option_name_for(c), c.id] }, value)
    end

    def option_name_for(user)
      I18n.t("work/shift.choosing_as", name: user.decorate.full_name)
    end

    # Users this user can choose as (must have a nonzero share) for the current period.
    def candidates
      [options[:chooser]] + period.shares.nonzero.where(user_id: candidate_ids).includes(:user).map(&:user)
    end

    def candidate_ids
      options[:chooser].household.users.pluck(:id) - [options[:chooser].id]
    end

    def period
      set[:period].object
    end
  end
end
