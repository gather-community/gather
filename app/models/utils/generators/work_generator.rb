# frozen_string_literal: true

module Utils
  module Generators
    # Generates work period, jobs, etc.
    class WorkGenerator < Generator
      attr_accessor :community, :period, :period_start, :period_end, :jobs

      def initialize(community:)
        self.community = community
        self.jobs = []
      end

      def generate_samples
        self.period_start = Time.zone.today.beginning_of_month
        self.period_end = (Time.zone.today + 3.months).end_of_month
        self.period = create(:work_period, :with_shares, community: community, quota_type: "by_person",
          name: I18n.t("sample_data.work.period"), starts_on: period_start, ends_on: period_end)
        generate_jobs
        generate_assignments
      end

      private

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength

      def generate_jobs
        jobs << create(:work_job, :with_reminder,
          title: job_title(:mow_team), period: period, hours: 8,
          slot_type: "fixed", time_type: "full_period", shift_count: 1, shift_slots: 4)
        jobs << create(:work_job, :with_reminder,
          title: job_title(:closer), period: period, hours: 4, slot_type: "fixed",
          time_type: "date_only", shift_count: 2, shift_slots: 1,
          shift_starts: [period_start, period_start + 1.month],
          shift_ends: [period_start.end_of_month, (period_start + 1.month).end_of_month])
        jobs << create(:work_job, :with_reminder,
          title: job_title(:work_day), period: period, hours: 3, slot_type: "full_single",
          time_type: "date_time", shift_count: 1, shift_slots: Work::Shift::UNLIMITED_SLOTS,
          shift_starts: [(period_start + 10.days).in_time_zone + 12.hours],
          shift_ends: [(period_start + 10.days).in_time_zone + 15.hours])
        jobs << create(:work_job, :with_reminder,
          title: I18n.t("starter_content.meal_roles.head_cook.title"), period: period, hours: 3,
          slot_type: "fixed", time_type: "date", shift_count: 3, shift_slots: 1,
          shift_starts: [period_start + 7.days, period_start + 14.days, period_start + 21.days],
          shift_ends: [period_start + 8.days, period_start + 15.days, period_start + 22.days])
      end

      def generate_assignments
        users = User.adults.active.shuffle
        2.times { jobs[0].shifts[0].assignments.create!(user: users.pop) }
        jobs[1].shifts[1].assignments.create!(user: users.pop)
        5.times { jobs[2].shifts[0].assignments.create!(user: users.pop) }
      end

      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      def job_title(key)
        I18n.t("sample_data.work.jobs.#{key}")
      end
    end
  end
end
