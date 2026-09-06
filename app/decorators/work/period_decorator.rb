# frozen_string_literal: true

module Work
  class PeriodDecorator < ApplicationDecorator
    delegate_all

    def round_duration_options
      (1..15).to_a.map { |i| [t("work/period.num_minutes", count: i), i] }
    end

    # Human-friendly start–end range including the year. When the period runs from the first of a
    # month to the last of a month, the days are suppressed (e.g. "Jan 2026", "Jan–Apr 2026",
    # "Dec 2026–Jan 2027"); otherwise the days are shown (e.g. "Jan 15–Apr 10 2026").
    def date_range
      if full_months?
        if starts_on.year != ends_on.year
          "#{h.l(starts_on, format: :month_year)}–#{h.l(ends_on, format: :month_year)}"
        elsif starts_on.month == ends_on.month
          h.l(starts_on, format: :month_year)
        else
          "#{h.l(starts_on, format: :month)}–#{h.l(ends_on, format: :month_year)}"
        end
      elsif starts_on.year != ends_on.year
        "#{h.l(starts_on, format: :default)}–#{h.l(ends_on, format: :default)}"
      else
        "#{h.l(starts_on, format: :month_day)}–#{h.l(ends_on, format: :default)}"
      end
    end

    def show_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :review_notices, icon: "bullhorn",
                                                path: h.review_notices_work_period_path(object)),
        ActionLink.new(object, :clone, icon: "copy", path: h.new_work_period_path(clone_from: id)),
        ActionLink.new(object, :edit, icon: "pencil", path: h.edit_work_period_path(object))
      )
    end

    def notices_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :send_notices, icon: "paper-plane", method: :post, btn_class: :primary,
                                              path: h.send_notices_work_period_path(object))
      )
    end

    def edit_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :destroy, icon: "trash", path: h.work_period_path(object),
                                         method: :delete, confirm: {name: name})
      )
    end

    private

    def full_months?
      starts_on == starts_on.beginning_of_month && ends_on == ends_on.end_of_month
    end
  end
end
