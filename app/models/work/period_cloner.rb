# frozen_string_literal: true

module Work
  # PORO for cloning work periods
  class PeriodCloner
    include ActiveModel::Model

    attr_accessor :old_period, :new_period

    # Called when newp is a blank, unpersisted period.
    def copy_attributes_and_shares
      %i[pick_type quota_type round_duration max_rounds_per_worker workers_per_round].each do |attrib|
        new_period[attrib] = old_period[attrib]
      end

      old_period.shares.includes(:user).each do |share|
        next if share.user.inactive?
        new_period.shares.build(period: new_period, user_id: share.user_id, portion: share.portion)
      end
    end
  end
end
