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
  end
end
