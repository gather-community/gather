# frozen_string_literal: true

module Work
  # Methods used by multiple work decorators.
  class WorkDecorator < ApplicationDecorator
    protected

    def full_community_icon
      h.icon_tag("users", title: t("work/jobs.full_community"))
    end

    # Rounds to the next .5 and displays fractional part only if nonzero
    def round_next_half(num)
      return nil if num.blank?

      to_int_if_no_fractional_part((num * 2).ceil.to_f / 2)
    end
  end
end
