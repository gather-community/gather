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
module Meals
  # Models a reminder for a meal role.
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
