# frozen_string_literal: true

module Work
  class ReportDecorator < WorkDecorator
    delegate_all

    def fixed_slot_hours_rounded
      fixed_slot_hours.round
    end

    def fixed_slots_rounded
      fixed_slots.round
    end

    def total_portions_rounded
      round_next_half(total_portions)
    end

    def quota_rounded
      round_next_half(quota)
    end

    def preassigned_hours_for(entity)
      num = entity.users.sum { |u| by_user.dig(u.id, :preassigned) || 0 }.round(1)
      h.number_with_precision(num, precision: 1)
    end

    def regular_hours_for(entity)
      num = entity.users.sum { |u| by_user.dig(u.id, :fixed_slot) || 0 }.round(1)
      h.number_with_precision(num, precision: 1)
    end

    def regular_pct_for(entity)
      denom = entity.users.sum { |u| shares_by_user[u.id].try(:adjusted_quota) || 0 }
      return "" if denom.zero?

      num = entity.users.sum { |u| by_user.dig(u.id, :fixed_slot) || 0 } * 100
      h.number_to_percentage(num / denom, precision: 0)
    end

    def fc_job_hours_for(fcjob, entity)
      num = entity.users.sum { |u| by_user.dig(u.id, fcjob) || 0 }.round(1)
      h.number_with_precision(num, precision: 1)
    end

    def fc_job_pct_for(fcjob, entity)
      denom = fcjob.hours * entity.users.sum { |u| shares_by_user[u.id].try(:portion) || 0 }
      return "" if denom.zero?

      num = entity.users.sum { |u| by_user.dig(u.id, fcjob) || 0 } * 100
      h.number_to_percentage(num / denom, precision: 0)
    end
  end
end
