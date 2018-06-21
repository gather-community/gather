# frozen_string_literal: true

module Work
  class ShiftDecorator < WorkDecorator
    delegate_all

    def mine?
      user_signed_up?(h.current_user)
    end

    def job_title_with_icon
      str = "".html_safe << job_title
      str << " " << full_community_icon if full_community?
      str
    end

    def link_with_icon
      link = h.link_to(job_title, object, class: "title")
      link << " " << full_community_icon if full_community?
      link
    end

    # Returns formatted times. Examples:
    # Sun Jul 08 4:15pm–6:15pm
    # Wed May 02–Wed May 30
    # May–August
    def times
      if starts_at.to_date == ends_at.to_date
        if job_date_time?
          starts_at_formatted << "–" << h.l(ends_at, format: :time_only).strip
        else
          starts_at_formatted
        end
      elsif !job_date_time? && starts_and_ends_on_month_boundaries?
        [h.l(starts_at, format: "%B"), h.l(ends_at, format: "%B")].uniq.join("–")
      else
        "#{starts_at_formatted}–#{ends_at_formatted}"
      end
    end

    def starts_at_formatted
      h.l(starts_at, format: time_format).strip.gsub(/\s\s+/, " ")
    end

    def ends_at_formatted
      h.l(ends_at, format: time_format).strip.gsub(/\s\s+/, " ")
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

    def assginees_with_empty_slots(style:)
      blobs = (worker_names << empty_total_slots).compact
      blobs = [t("work.no_signups")] if blobs.empty?
      blobs.map! { |b| h.content_tag(:li, b) } if style == :li
      separator = style == :comma_sep ? ", " : ""
      blobs.reduce(&sep(separator))
    end

    def worker_names
      assignments.by_user_name.map do |a|
        name = a.user.decorate.full_name(show_inactive: true)
        link = h.link_to(name, a.user)
        link << " " << h.icon_tag("thumb-tack") if a.preassigned?
        link
      end
    end

    def empty_total_slots
      return nil if empty_slots.zero? || full_community?
      t("work/shift.slots_open", count: empty_slots)
    end

    def show_action_link_set
      links = [ActionLink.new(object, :edit_job, icon: "pencil", path: h.edit_work_job_path(job),
                                                 permitted: h.policy(job).edit?)]
      links <<
        if user_signed_up?(h.current_user)
          ActionLink.new(object, :unsignup, icon: "times", path: h.unsignup_work_shift_path(object),
                                            btn_class: :danger, method: :delete, confirm: true)
        else
          ActionLink.new(object, :signup, icon: "bolt", path: h.signup_work_shift_path(object),
                                          btn_class: :primary, method: :post)
        end
      ActionLinkSet.new(*links)
    end

    private

    def time_format
      @time_format ||= job_date_time? ? :datetime_no_yr : :short_date
    end
  end
end
