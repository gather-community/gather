module Work
  class ShiftDecorator < ApplicationDecorator
    delegate_all

    def times
      if starts_at.to_date == ends_at.to_date
        if job_date_time?
          starts_at_formatted << "–" << h.l(ends_at, format: :time_only).strip
        else
          starts_at_formatted
        end
      else
        "#{starts_at_formatted}–#{ends_at_formatted}"
      end
    end

    def starts_at_formatted
      h.l(starts_at, format: time_format).strip
    end

    def ends_at_formatted
      h.l(ends_at, format: time_format).strip
    end

    def hours_formatted
      to_int_if_no_fractional_part(hours)
    end

    def photos
      imgs = assignments[0...4].map { |a| h.user_photo_if_permitted(a.user, :thumb) }
      imgs.insert(imgs.size - 2, h.tag(:br)) if imgs.size > 2
      imgs.reduce(:<<)
    end

    private

    def time_format
      @time_format ||= job_date_time? ? :datetime_no_yr : :short_date
    end
  end
end
