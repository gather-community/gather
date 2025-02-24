# frozen_string_literal: true

module Work
  # Lens to indicate who is being chosen for (for proxy situations).
  class ChooseeLens < Lens::SelectLens
    param_name :choosee

    def initialize(options:, **params)
      options[:clearable] = false
      options[:global] = true # Global so that it doesn't cause a clear link to show (sort of a hack).
      options[:floating] = true
      super
    end

    def render
      h.tag.form(select_tag, class: "form-inline floating-lens hidden-print")
    end

    private

    def chooser
      options[:chooser]
    end

    # Users this user can choose as.
    def possible_options
      [chooser].concat(chooser.household.users, users_with_chooser_as_proxy).uniq
    end

    def name_for_object_option(user)
      I18n.t("work/shift.choosing_as", name: user.decorate.full_name)
    end

    def users_with_chooser_as_proxy
      User.active.where(job_choosing_proxy_id: chooser.id)
    end

    def period
      set[:period].selection
    end
  end
end
