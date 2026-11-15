# frozen_string_literal: true

module Work
  # Sends job choosing notices.
  class JobChoosingNoticeJob < ApplicationJob
    def perform(period_id)
      with_object_in_cluster_context(klass: Period, id: period_id) do |period|
        Work::Share.for_period(period).nonzero.each do |share|
          data = {share_id: share.id, period_id: period_id}
          each_notification_recipient(share.user, kind: :job_choosing_notice, data: data) do |user|
            WorkMailer.with(recipient: user).job_choosing_notice(share).deliver_now
          end
        end
      end
    end
  end
end
