# frozen_string_literal: true

module People
  # Fully (hard) deletes a household and all of its members. Each member's authored records are
  # reassigned to the "Deleted Member" placeholder (via People::UserDeletion) before the
  # household is destroyed, so the household → users cascade doesn't hit foreign-key violations.
  # Billing accounts, statements, transactions, signups, vehicles, pets and emergency contacts
  # cascade away via the Household model's dependent: :destroy.
  #
  # `blockers` returns human-readable reasons deletion is currently refused (empty ⇒ proceed).
  class HouseholdDeletion
    attr_reader :household, :actor

    def initialize(household:, actor:)
      @household = household
      @actor = actor
    end

    # @return [Array<String>] reasons deletion is blocked; empty means it may proceed.
    def self.blockers(household)
      reasons = []
      if Billing::Account.outstanding_balance?(household)
        reasons << I18n.t("people.deletion.blockers.household_balance", name: household.name)
      end
      wards = external_wards(household)
      if wards.any?
        reasons << I18n.t("people.deletion.blockers.external_ward", names: wards.map(&:name).to_sentence)
      end
      reasons << I18n.t("people.deletion.blockers.last_admin") if removes_last_admin?(household)
      reasons
    end

    # Children of this household's members who live in a DIFFERENT household. Deleting the
    # household would orphan them (a child requires a guardian), so we block instead.
    def self.external_wards(household)
      household.users.flat_map(&:children).uniq.select { |child| child.household_id != household.id }
    end

    # True when the community has an active admin but every one of them lives in this household,
    # so deleting it would leave the community with no admin.
    def self.removes_last_admin?(household)
      admins = User.in_community(household.community_id).active.with_admin_role
      admins.exists? && admins.where.not(household_id: household.id).none?
    end

    def perform!
      raise People::UndeletableError if household.deleted_placeholder?
      ActiveRecord::Base.transaction do
        household.users.to_a.each { |user| UserDeletion.new(user: user, actor: actor).reassign_only }
        household.destroy!
      end
    end
  end
end
