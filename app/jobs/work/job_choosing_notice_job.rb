# frozen_string_literal: true

module Work
  # Sends job choosing notices.
  class JobChoosingNoticeJob < ApplicationJob
    def perform(period_id)
      with_object_in_community_context(Period, period_id) do |period|
        Work::Share.for_period(period).nonzero.each { |s| WorkMailer.job_choosing_notice(s).deliver_now }
      end
    end
  end
end
