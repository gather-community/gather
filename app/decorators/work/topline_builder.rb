# frozen_string_literal: true

module Work
  # Builds the topline string for the shifts page.
  class ToplineBuilder < ApplicationDecorator
    attr_accessor :period

    delegate :quota_type, to: :period

    def initialize(period)
      self.period = period
    end

    def to_s
      return "" if !period.open? || period.quota_none? || share.zero?
      h.content_tag(:div, class: "shifts-topline") do
        (needs.empty? ? done : not_done).html_safe
      end
    end

    private

    def done
      chunks = buckets.map do |bucket|
        subkey = bucket == :regular ? "#{quota_type}.count" : "job_phrase.count"
        title = bucket == :regular ? nil : bucket.title
        h.t("work.topline.#{subkey}", count: hours[bucket], title: title)
      end
      h.t("work.topline.done") << " " << join_chunks(chunks)
    end

    def not_done
      chunks = [chunk_for_need(needs[0], first: true)]
      needs[1..-1].each { |need| chunks << chunk_for_need(need) }
      join_chunks(chunks)
    end

    def join_chunks(chunks)
      left = chunks.size > 2 ? chunks[0..-2].join(", ") << "," : chunks[0]
      right = chunks.size > 1 ? chunks[-1] : nil
      [left, right].compact.join(" and ") << "."
    end

    def chunk_for_need(need, first: false)
      subkey = first ? "#{quota_type}.more_needed.#{need[:kind]}" : "job_phrase"
      params = need.slice(:count, :quota)
      params[:title] = need[:job].title if need[:job]
      h.t("work.topline.#{subkey}", params)
    end

    def needs
      return @needs if @needs
      @needs = []
      buckets.each do |bucket|
        next unless hours[bucket] < quotas[bucket]
        @needs << {
          kind: bucket == :regular ? :regular : :job,
          job: bucket == :regular ? nil : bucket,
          quota: round(quotas[bucket]),
          count: round(quotas[bucket] - hours[bucket])
        }
      end
      @needs
    end

    def hours
      @hours ||= buckets.map { |b| [b, assigned_hours_for(b)] }.to_h
    end

    def quotas
      @quotas ||= buckets.map { |b| [b, quota_for(b)] }.to_h
    end

    def quota_for(bucket)
      (bucket == :regular ? period.quota : bucket.hours) * share
    end

    def assigned_hours_for(bucket)
      scope = Assignment.where(user: users).includes(shift: :job)
      if bucket == :regular
        scope.merge(Job.fixed_slot).sum("work_jobs.hours")
      else
        # For full community jobs, shift hours are different from job hours, so SQL sum won't work.
        scope.where("work_shifts.job_id": bucket.id).to_a.sum(&:shift_hours)
      end
    end

    def share
      @share ||= Share.for_period(period).where(user: users).sum(:portion)
    end

    def users
      @users ||= period.quota_by_household? ? h.current_user.household.users : [h.current_user]
    end

    def buckets
      @buckets ||= [:regular] + Job.full_community.in_period(period)
    end

    def round(num)
      to_int_if_no_fractional_part((num * 2).ceil.to_f / 2)
    end
  end
end
