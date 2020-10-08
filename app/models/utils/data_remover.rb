# frozen_string_literal: true

module Utils
  # Removes all data from the current cluster, except for non-fake users and their households.
  class DataRemover
    def initialize(cluster_id)
      raise "CLUSTERS DON'T MATCH, DANGER" unless ActsAsTenant.current_tenant.id == cluster_id
    end

    def remove
      to_destroy_all = [Billing::Account, Meals::Meal, Meals::Formula, Reservations::Reservation,
                        Reservations::Protocol, Reservations::Resource, Reservations::SharedGuidelines,
                        People::Memorial]
      to_destroy_all.each(&:destroy_all)

      non_fake_household_ids = User.where(fake: false).pluck(:household_id)
      User.where(fake: true).destroy_all
      Household.where.not(id: non_fake_household_ids).destroy_all
    end
  end
end
