# frozen_string_literal: true

module Search
  # Limits Gather search results to records the user is allowed to see.
  #
  # Works in two stages. The coarse rules (whole kinds the user can't see, and transactions on other
  # households' accounts) go into the Elasticsearch query via `es_filters`, so hidden records can't
  # crowd visible ones out of the result size limit. Then `filter` checks each remaining hit against
  # its model's policy scope, which covers the finer rules (meal invitations, group visibility,
  # calendar access, inactive users, etc.).
  class Visibility
    # Kinds whose visibility is decided by a policy scope on the record's model.
    SCOPED_MODELS = {
      "wiki_page" => Wiki::Page,
      "event" => Calendars::Event,
      "calendar" => Calendars::Calendar,
      "group" => Groups::Group,
      "user" => User,
      "household" => Household,
      "meal" => Meals::Meal,
      "vehicle" => People::Vehicle,
      "transaction" => Billing::Transaction
    }.freeze

    attr_reader :user, :community

    def initialize(user:, community:)
      @user = user
      @community = community
    end

    # Extra clauses for the Elasticsearch bool filter.
    def es_filters
      filters = []
      filters << {bool: {must_not: {terms: {kind: hidden_kinds}}}} if hidden_kinds.any?
      filters << {
        bool: {
          should: [
            {bool: {must_not: {term: {kind: "transaction"}}}},
            {terms: {account_id: visible_account_ids}}
          ],
          minimum_should_match: 1
        }
      }
      filters
    end

    # Returns the results that pass their model's policy scope, in their original order.
    def filter(results)
      visible_ids = results.group_by { |r| r._source.kind }.to_h do |kind, hits|
        model = SCOPED_MODELS[kind]
        ids = hits.map { |r| r._source.id }
        [kind, model ? Pundit.policy_scope!(user, model).where(id: ids).pluck(:id).to_set : ids.to_set]
      end
      results.select { |r| visible_ids[r._source.kind].include?(r._source.id) }
    end

    private

    # Emergency contacts and pets are shown only alongside a household's personal info, which is limited
    # to the household's own community. Memorials have a kind-wide index permission.
    def hidden_kinds
      @hidden_kinds ||= [].tap do |kinds|
        kinds.concat(%w[emergency_contact pet]) unless household_policy.show_personal_info?
        kinds << "memorial" unless memorial_policy.index?
      end
    end

    def household_policy
      HouseholdPolicy.new(user, Household.new(community: community))
    end

    def memorial_policy
      People::MemorialPolicy.new(user, People::Memorial.new(community: community))
    end

    def visible_account_ids
      Pundit.policy_scope!(user, Billing::Account).pluck(:id)
    end
  end
end
