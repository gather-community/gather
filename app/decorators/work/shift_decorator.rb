# frozen_string_literal: true

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
      imgs = assignments[0...4].map { |a| a.user.decorate.photo_if_permitted(:thumb) }
      imgs.insert(imgs.size - 2, h.tag(:br)) if imgs.size > 2
      imgs.reduce(:<<)
    end

    def requester_name
      job_requester.try(:name)
    end

    def assginees_with_empty_slots
      [assignee_names.presence, empty_slot_count].compact.reduce(&sep(", "))
    end

    def assignee_names
      links = assignments.by_user_name.map { |a| h.link_to(a.user.decorate.name_with_inactive, a.user) }
      links.reduce(&sep(", "))
    end

    def empty_slot_count
      empty_slots.positive? ? t("work/shifts.empty_slots", count: empty_slots) : nil
    end

    def show_action_link_set
      signup_link =
        if user_signed_up?(h.current_user)
          ActionLink.new(object, :unsignup, icon: "times", path: h.unsignup_work_shift_path(object),
                                          method: :delete, confirm: true)
        else
          ActionLink.new(object, :signup, icon: "bolt", path: h.signup_work_shift_path(object),
                                          primary: true, method: :post)
        end
      ActionLinkSet.new(signup_link)
    end

    private

    def time_format
      @time_format ||= job_date_time? ? :datetime_no_yr : :short_date
    end
  end
end
