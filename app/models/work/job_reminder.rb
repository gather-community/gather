# frozen_string_literal: true

module Work
# == Schema Information
#
# Table name: reminders
#
#  id            :bigint           not null, primary key
#  abs_rel       :string           default("relative"), not null
#  abs_time      :datetime
#  note          :string
#  rel_magnitude :decimal(10, 2)
#  rel_unit_sign :string
#  type          :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  cluster_id    :integer          not null
#  job_id        :bigint
#  role_id       :bigint
#
# Indexes
#
#  index_reminders_on_cluster_id_and_job_id  (cluster_id,job_id)
#  index_reminders_on_role_id                (role_id)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (job_id => work_jobs.id)
#  fk_rails_...  (role_id => meal_roles.id)
#
  # Models a reminder to do a job, or part of a job.
  class JobReminder < Reminder
    belongs_to :job, class_name: "Work::Job", inverse_of: :reminders

    protected

    def delivery_maintainer
      JobReminderMaintainer.instance
    end
  end
end
