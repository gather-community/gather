# frozen_string_literal: true

module Utils
  # Removes all data from the current cluster, except for non-fake users and their households.
  class SampleDataRemover
    def initialize(cluster_id)
      raise "CLUSTERS DON'T MATCH, DANGER" unless ActsAsTenant.current_tenant.id == cluster_id
    end

    def remove
      Billing::Account.update_all(balance_due: 0, current_balance: 0, due_last_statement: nil,
                                  last_statement_id: nil, last_statement_on: nil,
                                  total_new_charges: 0, total_new_credits: 0)
      to_destroy_all = [Billing::Transaction, Billing::Statement, Meals::Meal,
                        Calendars::Event, Calendars::Protocol, Calendars::Calendar,
                        Calendars::SharedGuidelines, People::Memorial]
      to_destroy_all.each(&:destroy_all)

      non_fake_household_ids = User.where(fake: false).pluck(:household_id)
      User.where(fake: true).destroy_all
      Billing::Account.where.not(household_id: non_fake_household_ids).destroy_all
      Household.where.not(id: non_fake_household_ids).destroy_all
    end
  end
end
