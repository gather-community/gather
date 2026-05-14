# frozen_string_literal: true

module Work
  # Sends job choosing notices.
  class JobChoosingNoticeJob < ApplicationJob
    def perform(period_id)
      with_object_in_cluster_context(klass: Period, id: period_id) do |period|
        Work::Share.for_period(period).nonzero.each do |s|
          with_mail_delivery_resilience(data: {share_id: s.id, period_id: period_id}) do
            WorkMailer.job_choosing_notice(s).deliver_now
          end
        end
      end
    end
  end
end
