# frozen_string_literal: true

module Work
  # Parent controller for all work controllers.
  class WorkController < ApplicationController
    helper_method :sample_period

    protected

    def sample_period
      Period.new(community: current_community)
    end

    # Loads the period identified by the :period_id path segment into @period, if any.
    def load_period
      @period = Period.in_community(current_community).find_by(slug: params[:period_id])
    end

    # For landing (no period_id) pages: if exactly one selectable period exists, redirect straight
    # into it; otherwise load the selectable periods for the picker. Returns true iff redirected.
    def redirect_to_sole_period_or_load_selectable(section)
      @periods = Period.in_community(current_community).selectable.newest_first.to_a
      return false unless @periods.one?
      redirect_to(work_section_path(section, @periods.first))
      true
    end

    # Path to the given section (:signups/:jobs/:report) within a specific period.
    def work_section_path(section, period)
      case section
      when :signups then work_period_shifts_path(period)
      when :jobs then work_period_jobs_path(period)
      when :report then work_period_report_path(period)
      end
    end
  end
end
