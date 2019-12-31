# frozen_string_literal: true

module Groups
  # A group of users.
  class Group < ApplicationRecord
    include Deactivatable

    KINDS = %i[committee subcommittee team task_force club crew squad gang group].freeze
    AVAILABILITIES = %i[open closed everybody hidden].freeze

    self.table_name = "groups"

    acts_as_tenant :cluster

    has_many :affiliations, class_name: "Groups::Affiliation", dependent: :destroy, inverse_of: :group
    has_many :communities, through: :affiliations
    has_many :memberships, -> { by_kind_and_user_name }, class_name: "Groups::Membership",
                                                         dependent: :destroy, inverse_of: :group
    has_many :work_jobs, class_name: "Work::Job", foreign_key: :requester_id, dependent: :nullify,
                         inverse_of: :requester

    scope :in_community, lambda { |c|
      where("EXISTS(SELECT id FROM group_affiliations
        WHERE group_id = groups.id AND community_id = ?)", c.id)
    }
    scope :can_request_jobs, -> { where(can_request_jobs: true) }
    scope :visible, -> { where.not(availability: "hidden") }
    scope :visible_or_managed_by, lambda { |user|
      subq = "EXISTS (SELECT id FROM group_memberships WHERE user_id = #{user.id} AND kind = 'manager')"
      visible.or(where(subq))
    }
    scope :hidden_last, -> { order(arel_table[:availability].eq("hidden")) }
    scope :with_member_counts, lambda {
      select("groups.*, (SELECT
        CASE availability
        WHEN 'everybody' THEN
          (SELECT COUNT(users.id)
            FROM users INNER JOIN households ON users.household_id = households.id
            WHERE users.cluster_id = groups.cluster_id AND users.deactivated_at IS NULL AND child = 'f'
              AND households.community_id IN
              (SELECT community_id FROM group_affiliations WHERE group_id = groups.id))
          - (SELECT COUNT(id) FROM group_memberships WHERE group_id = groups.id AND kind = 'opt_out')
        ELSE (SELECT COUNT(id) FROM group_memberships WHERE group_id = groups.id AND kind != 'opt_out')
        END
      ) AS member_count")
    }
    scope :with_user, lambda { |user|
      subq = "(SELECT id FROM group_memberships WHERE group_id = groups.id AND user_id = ? AND kind IN ?)"
      clause = "(availability != 'everybody' AND EXISTS #{subq}) OR "\
        "(availability = 'everybody' AND NOT EXISTS #{subq})"
      where(clause, user, %w[joiner manager], user, %w[opt_out])
    }
    scope :by_name, -> { alpha_order(:name) }
    scope :by_type, lambda {
      # Translate the possible type values and use these to sort in the DB.
      whens = KINDS.map do |kind|
        translated = I18n.t("simple_form.options.groups_group.kind.#{kind}")
        "WHEN '#{kind}' THEN '#{translated}'"
      end
      order("LOWER(CASE kind #{whens.join(' ')} END)")
    }

    normalize_attributes :kind, :availability, :name

    accepts_nested_attributes_for :memberships, reject_if: :all_blank, allow_destroy: true

    before_validation :normalize
    after_update { Work::ShiftIndexUpdater.new(self).update }

    validate :name_unique_in_all_communities
    validate :at_least_one_affiliation

    def everybody?
      availability == "everybody"
    end

    def closed?
      availability == "closed"
    end

    def open?
      availability == "open"
    end

    def hidden?
      availability == "hidden"
    end

    def single_community?
      communities.size == 1
    end

    def managers
      @managers ||= memberships.managers.including_users_and_communities.map(&:user)
    end

    def joiners
      @joiners ||= memberships.joiners.including_users_and_communities.map(&:user)
    end

    def opt_outs
      @opt_outs ||= memberships.opt_outs.including_users_and_communities.map(&:user)
    end

    # members = managers + (everybody ? all active adults : joiners) - opt outs
    def members
      if everybody?
        # The scope on Users for everybody groups is defined here and in the with_member_counts scope also.
        # They should be consistent.
        User.active.adults.in_community(communities).including_communities.by_name - opt_outs
      else
        managers + joiners
      end
    end

    # Assumes membership records persisted. Assumes used only O(1) times. Use other methods for O(n).
    # Returns nil if user not a member.
    def membership_for(user)
      memberships.find_by(user_id: user)
    end

    def join(user)
      membership = membership_for(user)
      if everybody? && membership&.opt_out?
        membership.destroy
      elsif !everybody? && membership.nil?
        memberships.create!(user: user, kind: "joiner")
      end
    end

    def leave(user)
      membership = membership_for(user)
      if everybody? && !membership.nil? && !membership&.opt_out?
        membership.destroy
      elsif everybody? && membership.nil?
        memberships.create!(user: user, kind: "opt_out")
      elsif !everybody? && !membership.nil?
        membership.destroy
      end
    end

    private

    def normalize
      memberships.delete(memberships.to_a.select(&:joiner?)) if everybody?
      memberships.delete(memberships.to_a.select(&:opt_out?)) unless everybody?
    end

    def name_unique_in_all_communities
      return if name.blank?
      scope = self.class.where(name: name)
      scope = scope.where.not(id: id) if persisted?
      return if (communities & scope.to_a.flat_map(&:communities)).none?
      errors.add(:name, :taken)
    end

    def at_least_one_affiliation
      return if affiliations.reject(&:marked_for_destruction?).any?
      errors.add(:base, :at_least_one_affiliation)
    end
  end
end
