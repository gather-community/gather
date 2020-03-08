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

        # Max size in kilobytes
        max_message_size: 5_000,

        # People shouldn't be subscribing to lists directly as their subscription won't be sync'd back
        # to Gather. Also, lists won't be advertised so this should be rare.
        # So at least this way the moderators will be able to tell them not to do that.
        subscription_policy: "moderate",

        # "defer" means default processing
        default_member_action: "defer",

        # "hold" means send to moderators
        default_nonmember_action: "hold"
      }.freeze

      # Settings that will get reset on each sync.
      ENFORCED_SETTINGS = %i[advertised max_message_size subscription_policy].freeze

      acts_as_tenant :cluster

      attr_accessor :config

      belongs_to :domain
      belongs_to :group, inverse_of: :mailman_list

      normalize_attributes :name

      validate :check_outside_addresses

      before_save :clean_outside_addresses

      delegate :name, to: :domain, prefix: true

      def fqdn_listname
        "#{name}@#{domain_name}"
      end

      def list_memberships
        outside_memberships + owner_moderator_memberships + normal_memberships
      end

      def syncable?
        group&.active?
      end

      def remote_id?
        remote_id.present?
      end

      private

      def check_outside_addresses
        %i[outside_members outside_senders].each do |attrib|
          next if self[attrib].blank?
          self[attrib].split("\n").each_with_index do |line, number|
            next if line.strip.empty?
            address = Mail::Address.new(line)
            raise Mail::Field::FieldError unless address.address.match?(::User::EMAIL_REGEXP)
          rescue Mail::UnknownEncodingType, Mail::Field::FieldError
            errors.add(attrib, "Error on line #{number + 1} (#{line})")
            break
          end
        end
      end

      def clean_outside_addresses
        %i[outside_members outside_senders].each do |attrib|
          next if self[attrib].blank?
          cleaned = self[attrib].split("\n").map { |l| Mail::Address.new(l).to_s unless l.strip.empty? }
          send("#{attrib}=", cleaned.compact.join("\n"))
        end
      end

      def outside_memberships
        %i[outside_members outside_senders].flat_map do |attrib|
          role = attrib == :outside_members ? "member" : "nonmember"
          self[attrib].split("\n").map do |str|
            address = Mail::Address.new(str)
            mm_user = Mailman::User.new(display_name: address.display_name, email: address.address)
            ListMembership.new(mailman_user: mm_user, list_id: remote_id, role: role)
          end
        end
      end

      def owner_moderator_memberships
        # Groups that can administer this group must have at least the same communities if not more.
        ability_groups = Group.active.in_communities(group.communities)
        %i[administer moderate].flat_map do |ability|
          role = ability == :administer ? "owner" : "moderator"
          ability_groups.where("can_#{ability}_email_lists": true).flat_map do |ability_group|
            ability_group.members.map do |member|
              mm_user = Mailman::User.find_or_initialize_by(user: member)
              ListMembership.new(mailman_user: mm_user, list_id: remote_id, role: role)
            end
          end
        end
      end

      def normal_memberships
        group.members(user_eager_load: :group_mailman_user).map do |user|
          mm_user = user.group_mailman_user || Mailman::User.new(user: user)
          ListMembership.new(mailman_user: mm_user, list_id: remote_id, role: "member")
        end
      end
    end
  end
end
