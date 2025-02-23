# frozen_string_literal: true

module Groups
  module Mailman
    # Models a Mailman list.
    class List < ApplicationRecord
      include Wisper.model

      # Good initial settings for a lits.
      DEFAULT_SETTINGS = {
        advertised: false,
        dmarc_mitigate_action: "munge_from",
        archive_policy: "private",

        # Max size in kilobytes, so this is 5 MiB
        max_message_size: 5 * 1_024,

        # People shouldn't be subscribing to lists directly as their subscription won't be sync'd back
        # to Gather. Also, lists won't be advertised so this should be rare.
        # So at least this way the moderators will be able to tell them not to do that.
        subscription_policy: "moderate",

        # "defer" means default processing
        default_member_action: "defer",

        # What to do with mail from nonmembers (i.e. outsiders). We default this to 'hold' (send to
        # moderators) but currently don't enforce it because for smaller lists, e.g.
        # committee lists, this is a pain. We could perhaps add every person in the community as
        # a permitted sender, but this would have performance issues. If we start seeing spam
        # flowing as a result of this we may have to enforce.
        default_nonmember_action: "hold",

        # Disabling welcome messages for now because they are gross looking and probably not necessary
        # and they tend to be problematic when first migrating lists into the system.
        send_welcome_message: false
      }.freeze

      # Settings that will get reset on each sync.
      ENFORCED_SETTINGS = %i[advertised max_message_size subscription_policy].freeze

      acts_as_tenant :cluster

      attr_accessor :config

      belongs_to :domain
      belongs_to :group, inverse_of: :mailman_list

      normalize_attributes :name

      # Mailman's listname_chars setting defaults to [-_.0-9a-z]. Not keen to mess with it.
      validates :name, format: {with: /\A[-_.a-z0-9]+\z/}
      validates :domain_id, presence: true

      delegate :name, to: :domain, prefix: true
      delegate :communities, to: :group
      delegate :name, to: :group, prefix: true

      def fqdn_listname
        "#{name}@#{domain_name}"
      end

      def list_memberships
        owner_moderator_memberships + normal_memberships
      end

      def syncable?
        group&.active?
      end

      def remote_id?
        remote_id.present?
      end

      def list_memberships_for_group_membership_and_mm_user(mship, mm_user)
        roles = ["member"]
        if mship.manager?
          roles << "owner" if managers_can_administer?
          roles << "moderator" if managers_can_moderate?
        end
        roles.map { |r| ListMembership.new(mailman_user: mm_user, list_id: remote_id, role: r) }
      end

      def default_config
        DEFAULT_SETTINGS.merge(
          display_name: group_name,
          subject_prefix: "[#{name}] "
        )
      end

      private

      def owner_moderator_memberships
        # Groups that can administer this group must have at least the same communities if not more.
        ability_groups = Group.active.in_communities(group.communities)
        %i[administer moderate].flat_map do |ability|
          role = ability == :administer ? "owner" : "moderator"
          ability_groups.where("can_#{ability}_email_lists": true).flat_map do |ability_group|
            ability_group.members.map do |member|
              mm_user = find_or_initialize_mm_user_for(member)
              ListMembership.new(mailman_user: mm_user, list_id: remote_id, role: role)
            end
          end
        end
      end

      def normal_memberships
        group.computed_memberships(user_eager_load: :group_mailman_user).flat_map do |mship|
          next if mship.opt_out?

          mm_user = find_or_initialize_mm_user_for(mship.user)
          list_memberships_for_group_membership_and_mm_user(mship, mm_user)
        end.compact
      end

      # Keeps a local hash to prevent initializing multiple Mailman::User objs for the same user.
      def find_or_initialize_mm_user_for(user)
        @mm_users_by_user ||= {}
        return @mm_users_by_user[user] if @mm_users_by_user.key?(user)

        @mm_users_by_user[user] = Mailman::User.find_or_initialize_by(user: user)
      end
    end
  end
end
