# frozen_string_literal: true

module Meals
  class MealDecorator < ApplicationDecorator
    delegate_all

    def title_or_no_title
      title || "[No Menu]"
    end

    def link(*url_args)
      h.link_to(title_or_no_title, h.meal_url(object, *url_args))
    end

    def form_section(section, **options, &block)
      Meals::FormSection.new(self, section, **options, &block).html
    end

    def current_signup
      @current_signup ||= signups.detect { |s| s.household_id == h.current_user.household_id }&.decorate
    end

    def css_classes
      if cancelled?
        "cancelled"
      elsif current_signup.present?
        "signed-up"
      else
        ""
      end
    end

    def nonempty_menu_items
      Meals::Meal::MENU_ITEMS.map { |i| [i, self[i]] }.to_h.reject { |_, t| t.blank? }
    end

    # Returns a non-persisted SignupPolicy with this meal. Used for policy checks.
    def sample_signup
      @sample_signup ||= Signup.new(meal: object)
    end

    def location_name
      resources.first&.decorate&.name_with_prefix
    end

    def location_abbrv
      resources.first&.decorate&.abbrv_with_prefix
    end

    def served_at_datetime
      l(served_at)
    end

    def served_at_time_only
      l(served_at, format: :time_only)
    end

    def served_at_lens_dependent(time_lens)
      format = time_lens.upcoming? ? :wday_no_year : :default
      l(served_at, format: format)
    end

    def served_at_wday_no_year
      l(served_at, format: :wday_no_year)
    end

    def served_on_no_yr
      l(served_at.to_date, format: :wday_no_year)
    end

    # We should disable the "own" community checkbox for most users.
    def disable_community_checkbox?(community)
      disable = (object.community == community && community_invited?(community))
      disable ? "disabled" : nil
    end

    def cost
      @cost ||= object.cost.decorate
    end

    def allergen_options
      (community.settings.meals.allergens.split(/\s*,\s*/) + allergens).uniq.sort
    end

    def worker_links_for_role(role)
      assignments = assignments_by_role[role] || []
      links = assignments.map { |a| a.user.decorate.link(highlight: h.lenses[:user].value) }
      links.present? ? h.safe_join(links, ", ") : h.content_tag(:span, "[None]", class: "weak")
    end

    def show_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :edit, icon: "pencil", path: h.edit_meal_path(object)),
        ActionLink.new(object, :summary, icon: "file-text", path: h.summary_meal_path(object)),
        ActionLink.new(object, :reopen, icon: "unlock", path: h.reopen_meal_path(object),
                                        method: :put, confirm: true),
        ActionLink.new(object, :close, icon: "lock", path: h.close_meal_path(object),
                                       method: :put, confirm: true),
        ActionLink.new(object, :finalize, icon: "certificate", path: h.new_meal_finalize_path(object)),
        ActionLink.new(object, :cancel, icon: "ban", path: h.new_meal_message_path(object, cancel: 1)),
        ActionLink.new(object, :send_message, icon: "envelope", path: h.new_meal_message_path(object))
      )
    end

    def edit_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :destroy, icon: "trash", path: h.meal_path(object), method: :delete,
                                         confirm: {title: title_or_no_title})
      )
    end

    private

    def form_section_summarizer
      @form_section_summarizer ||= Meals::FormSectionSummarizer.new(self)
    end
  end
end
