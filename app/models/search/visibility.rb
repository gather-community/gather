# frozen_string_literal: true

module Search
  # Limits Gather search results to records the user is allowed to see.
  #
  # Works in two stages. The coarse rules (whole kinds the user can't see, and transactions on other
  # households' accounts) go into the Elasticsearch query via `es_filters`, so hidden records can't
  # crowd visible ones out of the result size limit. Then `filter` checks each remaining hit's id against
  # its model's policy scope, which covers the finer rules (meal invitations, group visibility, calendar
  # access, inactive users, etc.).
  #
  # `filter` only plucks ids, one query per kind, so it's cheap enough to run on every hit (the count and
  # pagination need them all). `load_hits` then loads full records, with what the details line needs,
  # for just the page being shown.
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

    # Kinds that es_filters hides or shows as a whole, so any record that comes back is visible.
    UNSCOPED_MODELS = {
      "emergency_contact" => People::EmergencyContact,
      "pet" => People::Pet,
      "memorial" => People::Memorial
    }.freeze

    # Kinds that belong to a household and are shown with it.
    HOUSEHOLD_KINDS = %w[emergency_contact pet vehicle].freeze

    # Associations the details line uses (see SearchHelper#search_result_details).
    PRELOADS = {
      "wiki_page" => [:updater],
      "event" => [:calendar, :eventlets],
      "calendar" => [:group],
      "user" => [household: :community],
      "meal" => [:calendars],
      "memorial" => [:user],
      "emergency_contact" => [:household],
      "pet" => [:household],
      "vehicle" => [:household],
      "transaction" => [account: :household]
    }.freeze

    # A search hit paired with its database record.
    Hit = Struct.new(:result, :record) do
      def kind = result._source.kind
      def source = result._source
    end

    attr_reader :user, :community

    def initialize(user:, community:)
      @user = user
      @community = community
    end

    # Extra clauses for the Elasticsearch bool filter.
    def es_filters
      filters = []
      filters << {bool: {must_not: {terms: {kind: hidden_kinds}}}} if hidden_kinds.any?
      filters << only_for_kind("transaction", {terms: {account_id: visible_account_ids}})
      # The event policy scope allows any event in the cluster, but a calendar's protocol can forbid
      # other communities from seeing it. The calendar scope applies that rule.
      filters << only_for_kind("event", {terms: {calendar_id: visible_calendar_ids}})
      filters
    end

    # Returns the results whose record passes its model's policy scope, in the original order. Results
    # whose record no longer exists (a stale index entry) are dropped too.
    def filter(results)
      visible = by_kind(results) { |relation, ids| relation.where(id: ids).pluck(:id).to_set }
      results.select { |r| visible[r._source.kind]&.include?(r._source.id) }
    end

    # Returns a Hit with its loaded record for each of the given (already filtered) results.
    def load_hits(results)
      records = by_kind(results) do |relation, ids, kind|
        relation = relation.includes(*PRELOADS[kind]) if PRELOADS.key?(kind)
        relation.where(id: ids).index_by(&:id)
      end
      results.filter_map do |r|
        record = records.dig(r._source.kind, r._source.id)
        Hit.new(r, record) if record
      end
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

    # Restricts hits of the given kind with the clause, leaving other kinds alone.
    def only_for_kind(kind, clause)
      {bool: {should: [{bool: {must_not: {term: {kind: kind}}}}, clause], minimum_should_match: 1}}
    end

    # Yields the visible-records relation and hit ids for each kind among the results, returning a hash
    # of kind to the block's result.
    def by_kind(results)
      results.group_by { |r| r._source.kind }.to_h do |kind, kind_results|
        relation = visible_relation(kind)
        ids = kind_results.map { |r| r._source.id }
        [kind, relation ? yield(relation, ids, kind) : {}]
      end
    end

    def visible_relation(kind)
      relation =
        if SCOPED_MODELS.key?(kind)
          Pundit.policy_scope!(user, SCOPED_MODELS[kind])
        elsif UNSCOPED_MODELS.key?(kind)
          UNSCOPED_MODELS[kind].all
        end
      return if relation.nil?
      HOUSEHOLD_KINDS.include?(kind) ? in_active_household_here(relation) : relation
    end

    # Pets, emergency contacts and vehicles show only for active households in this community. The
    # index can lag behind a household moving community or being deactivated, so check the database.
    def in_active_household_here(relation)
      relation.joins(:household).where(households: {community_id: community.id, deactivated_at: nil})
    end

    def visible_calendar_ids
      Pundit.policy_scope!(user, Calendars::Calendar).pluck(:id)
    end

    def visible_account_ids
      Pundit.policy_scope!(user, Billing::Account).pluck(:id)
    end
  end
end
