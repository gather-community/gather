# frozen_string_literal: true

module People
  # Fully (hard) deletes a user. Unlike deactivation, this removes the row and its PII. Records
  # the user authored that must survive as community history (meals, wiki pages/versions,
  # calendar events, meal imports) are first reassigned to the "Deleted Member" placeholder of
  # the record's own community (see Community#deleted_member); optional back-references are
  # nullified. Everything else cascades away via the User model's dependent: :destroy/:nullify.
  #
  # `blockers` returns human-readable reasons deletion is currently refused (empty ⇒ proceed);
  # the controller surfaces them as a flash while leaving the delete button enabled.
  class UserDeletion
    attr_reader :user, :actor

    def initialize(user:, actor:)
      @user = user
      @actor = actor
    end

    # @return [Array<String>] reasons deletion is blocked; empty means it may proceed.
    def self.blockers(user)
      reasons = []
      if user.adult? && Billing::Account.outstanding_balance?(user.household)
        reasons << I18n.t("people.deletion.blockers.balance", name: user.household_name)
      end
      kids = user.children.to_a
      if kids.any?
        reasons << I18n.t("people.deletion.blockers.guardian", names: kids.map(&:name).to_sentence)
      end
      reasons << I18n.t("people.deletion.blockers.last_admin") if last_active_admin?(user)
      reasons
    end

    # True when `user` is a community admin and the only remaining active admin in their community.
    def self.last_active_admin?(user)
      return false unless user.global_role?(:admin)
      User.in_community(user.community_id).active.with_admin_role.where.not(id: user.id).none?
    end

    def perform!
      raise People::UndeletableError if user.deleted_placeholder?
      ActiveRecord::Base.transaction do
        reassign_authored_records
        user.destroy!
      end
    end

    # Reassigns authored records without destroying the user. Used by HouseholdDeletion so the
    # household's user cascade doesn't hit foreign-key violations on shared records.
    def reassign_only
      reassign_authored_records
    end

    private

    def reassign_authored_records
      reassign(Meals::Meal.where(creator: user), :creator_id, &:community)
      reassign(Meals::Message.where(sender: user), :sender_id, &:community)
      reassign(Calendars::Event.where(creator: user), :creator_id, &:community)
      reassign(Meals::Import.where(user: user), :user_id, &:community)
      reassign(Wiki::Page.where(creator: user), :creator_id, &:community)
      reassign(Wiki::Page.where(updater: user), :updater_id, &:community)
      reassign(Wiki::PageVersion.where(updater: user), :updater_id) { |v| v.page.community }

      # Optional attribution — no need to preserve; nullify.
      Messaging::Transaction.where(creator: user).update_all(creator_id: nil)
      # Apex-level (not tenant-scoped) FK back-reference; nullify so destroy isn't blocked.
      ActsAsTenant.without_tenant do
        Communities::Signup.where(reviewed_by_id: user.id).update_all(reviewed_by_id: nil)
      end
    end

    # Repoints `column` on every record in `relation` to the deleted-member placeholder of that
    # record's own community (records may live in another community within the cluster). Uses
    # update_all to skip callbacks/validations — required because wiki versions are immutable
    # and events run heavy sync callbacks we must not fire here.
    def reassign(relation, column)
      relation.to_a.group_by { |record| yield(record) }.each do |community, records|
        placeholder = placeholder_for(community)
        relation.klass.where(id: records.map(&:id)).update_all(column => placeholder.id)
      end
    end

    def placeholder_for(community)
      (@placeholders ||= {})[community.id] ||= community.deleted_member
    end
  end
end
