# frozen_string_literal: true

module Meals
  # Models a reminder for a meal role.
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
  # Doesn't support absolute times since that wouldn't make sense.
  class RoleReminder < Reminder
    # Furthest distance into the future that a "days after" reminder will be honored.
    # We have to limit this because otherwise we end up having to compute/load too many objects.
    MAX_FUTURE_DISTANCE = 30.days

    belongs_to :role, class_name: "Meals::Role", inverse_of: :reminders, foreign_key: :role_id

    protected

    def delivery_maintainer
      RoleReminderMaintainer.instance
    end
  end
end
