# frozen_string_literal: true

module Work
  # Parent controller for all work controllers.
  class WorkController < ApplicationController
    helper_method :sample_period

    before_action :load_period

    protected

    def sample_period
      Period.new(community: current_community)
    end

    # Loads @period from the period slug in the URL — the :period_id segment on the scoped content
    # pages, or the :id on a periods CRUD page (e.g. /work/periods/summertime) — and hands it to the
    # nav so its sub-links stay within the current period. @period is nil on landing/index/new pages;
    # actions that require a period guard for that themselves.
    def load_period
      slug = params[:period_id].presence || params[:id].presence
      @period = Period.in_community(current_community).find_by(slug: slug) if slug
      nav_builder.current_period = @period
    end

    # For actions that can't function without a period, e.g. anything nested under the :period_id
    # segment. Lives here rather than on PeriodsController because the scoped content controllers
    # need it too.
    def require_period
      render_not_found unless @period
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
