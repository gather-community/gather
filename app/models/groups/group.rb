# frozen_string_literal: true

# == Schema Information
#
# Table name: groups
#
#  id                         :bigint           not null, primary key
#  availability               :string(10)       default("closed"), not null
#  can_administer_email_lists :boolean          default(FALSE), not null
#  can_moderate_email_lists   :boolean          default(FALSE), not null
#  can_request_jobs           :boolean          default(FALSE), not null
#  cluster_id                 :integer          not null
#  created_at                 :datetime         not null
#  deactivated_at             :datetime
#  description                :string(255)
#  kind                       :string(32)       default("committee"), not null
#  name                       :string(64)       not null
#  updated_at                 :datetime         not null
#
module Groups
  # A group of users.
  class Group < ApplicationRecord
    include Wisper.model
    include Deactivatable

    KINDS = %i[committee subcommittee team task_force club crew circle squad group].freeze
    AVAILABILITIES = %i[open closed everybody hidden].freeze

    self.table_name = "groups"

    acts_as_tenant :cluster

    has_many :affiliations, class_name: "Groups::Affiliation", dependent: :destroy, inverse_of: :group
    has_many :communities, through: :affiliations
    has_many :memberships, -> { by_kind_and_user_name }, class_name: "Groups::Membership",
      dependent: :destroy, inverse_of: :group
    has_many :work_jobs, class_name: "Work::Job", foreign_key: :requester_id, dependent: :nullify,
      inverse_of: :requester
    has_many :work_periods_as_meal_job_requester, class_name: "Work::Period",
      foreign_key: :meal_job_requester_id,
      dependent: :nullify,
      inverse_of: :meal_job_requester
    has_many :events, class_name: "Calendars::Event", dependent: :nullify, inverse_of: :group
    has_many :gdrive_item_groups, class_name: "GDrive::ItemGroup", dependent: :destroy, inverse_of: :group
    has_one :mailman_list, class_name: "Groups::Mailman::List", dependent: :destroy, inverse_of: :group

    scope :in_community, lambda { |c|
      where("EXISTS(SELECT id FROM group_affiliations
        WHERE group_id = groups.id AND community_id IN (?))", Array.wrap(c).map(&:id))
    }
    # Matches groups that are in AT LEAST ALL the same communities as the passed array.
    scope :in_communities, ->(cmtys) { cmtys.inject(all) { |rel, c| rel.in_community(c) } }
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
            WHERE users.cluster_id = groups.cluster_id
              AND users.deactivated_at IS NULL
              AND full_access = 't'
              AND households.community_id IN
              (SELECT community_id FROM group_affiliations WHERE group_id = groups.id))
          - (SELECT COUNT(id) FROM group_memberships WHERE group_id = groups.id AND kind = 'opt_out')
        ELSE (SELECT COUNT(id) FROM group_memberships WHERE group_id = groups.id AND kind != 'opt_out')
        END
      ) AS member_count")
    }
    scope :with_user, lambda { |user|
      subq = "(SELECT id FROM group_memberships WHERE group_id = groups.id AND user_id = ? AND kind IN (?))"
      memb_clause = "(availability != 'everybody' AND EXISTS #{subq}) OR " \
        "(availability = 'everybody' AND NOT EXISTS #{subq})"
      affil_clause = "? IN (SELECT community_id FROM group_affiliations WHERE group_id = groups.id)"
      where(memb_clause, user, %w[joiner manager], user, %w[opt_out])
        .where(affil_clause, user.community_id)
    }
    scope :by_name, -> { alpha_order(:name) }
    scope :by_type, lambda {
      # Translate the possible type values and use these to sort in the DB.
      whens = KINDS.map do |kind|
        translated = I18n.t("simple_form.options.groups_group.kind.#{kind}")
        "WHEN '#{kind}' THEN '#{translated}'"
      end
      order(Arel.sql("LOWER(CASE kind #{whens.join(" ")} END)"))
    }

    normalize_attributes :kind, :availability, :name

    accepts_nested_attributes_for :memberships, reject_if: :all_blank, allow_destroy: true
    accepts_nested_attributes_for :mailman_list, allow_destroy: true

    before_validation :normalize
    before_validation :clear_mailman_list_if_empty_name

    validates :name, presence: true
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

    # Checks if associated with no communities. Hits the DB every time on purpose.
    def no_communities?
      communities.count.zero?
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

    # computed_memberships = persisted_memberships + (ephemeral memberships for all other active full users)
    def computed_memberships(user_eager_load: nil)
      kinds = everybody? ? %i[opt_out manager] : %i[joiner manager]
      matching_mships = memberships.where(kind: kinds).including_users_and_communities
      matching_mships = matching_mships.includes(user: user_eager_load) unless user_eager_load.nil?
      matching_mships = matching_mships.to_a
      if everybody?
        # The scope on Users for everybody groups is defined here and in the with_member_counts scope also.
        # They should be consistent.
        all_users = ::User.active.full_access.in_community(communities).including_communities.by_name
        all_users = all_users.includes(user_eager_load) unless user_eager_load.nil?
        mships_by_user = matching_mships.index_by(&:user)
        all_users.each do |user|
          next if mships_by_user.key?(user)
          matching_mships << Membership.new(group: self, user: user, kind: "joiner")
        end
      end
      matching_mships
    end

    # members = managers + (everybody ? all active full users : joiners) - opt outs
    def members(**args)
      computed_memberships(**args).map { |mship| mship.opt_out? ? nil : mship.user }.compact
    end

    # Assumes membership records persisted. Assumes used only O(1) times. Use other methods for O(n).
    # Returns nil if user not a member.
    def membership_for(user)
      memberships.find_by(user_id: user)
    end

    def member?(user)
      mship = membership_for(user)
      everybody? ? mship.nil? || !mship.opt_out? : !mship.nil?
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

    def clear_mailman_list_if_empty_name
      # If list doesn't pre-exist and no name is given, we're assuming they didn't fill in the form.
      if mailman_list&.new_record? && mailman_list.name.blank?
        self.mailman_list = nil
      end
    end
  end
end
