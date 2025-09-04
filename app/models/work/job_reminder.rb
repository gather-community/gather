# frozen_string_literal: true

# == Schema Information
#
# Table name: reminders
#
#  id            :bigint           not null, primary key
#  abs_rel       :string           default("relative"), not null
#  abs_time      :datetime
#  cluster_id    :integer          not null
#  created_at    :datetime         not null
#  job_id        :bigint
#  note          :string
#  rel_magnitude :decimal(10, 2)
#  rel_unit_sign :string
#  role_id       :bigint
#  type          :string           not null
#  updated_at    :datetime         not null
#
module Work
  # Models a reminder to do a job, or part of a job.
  class JobReminder < Reminder
    belongs_to :job, class_name: "Work::Job", inverse_of: :reminders

    protected

    def delivery_maintainer
      JobReminderMaintainer.instance
    end
  end
end
