# frozen_string_literal: true

module Notifications
  # Works out who should actually get a notification, given the people a caller wants to tell.
  #
  # Callers decide who a notification is about: the meal team, a household, the coordinators. This class
  # applies the rules every notification shares:
  # - Households become their members.
  # - A child we can't reach directly is reached through their guardians.
  # - Users we can't or shouldn't reach (fake users, unconfirmed full-access users) are dropped.
  # - Inactive users are handled according to the kind's `include_inactive` rule (see Catalog).
  # - Users who turned the kind off for this channel are dropped.
  #
  # Configurable notifications are sent one recipient per message, so the caller loops over the result:
  #
  #   Notifications::Recipients.resolve(signup.household, kind: :meal_reminder).each do |user|
  #     MealMailer.with(recipient: user).meal_reminder(signup).deliver_now
  #   end
  class Recipients
    attr_reader :kind, :channel

    def self.resolve(targets, kind:, channel: :email)
      new(kind: kind, channel: channel).resolve(targets)
    end

    def initialize(kind:, channel: :email)
      @kind = kind.is_a?(Catalog::Kind) ? kind : Catalog.find(kind)
      raise ArgumentError, "Unknown channel: #{channel}" unless Catalog::CHANNELS.include?(channel)
      @channel = channel
    end

    # Targets can be users, households, or raw addresses (strings) for the channel.
    # Returns users and raw addresses, without duplicates.
    def resolve(targets)
      recipients = Array.wrap(targets).compact.flat_map { |target| expand(target) }.compact.uniq
      recipients = apply_inactive_rule(recipients)
      recipients.reject { |r| r.is_a?(User) && !r.notification_enabled?(kind.key, channel: channel) }
    end

    private

    def expand(target)
      case target
      when User then expand_user(target)
      when Household then target.users.flat_map { |user| expand_user(user, via_household: true) }
      when String then target.presence
      else raise ArgumentError, "Invalid notification target: #{target.inspect}"
      end
    end

    # We reach children we can't contact directly through their guardians, except when going via a
    # household. Not all of a child's guardians live in the child's household, so a household notification
    # reaching a guardian elsewhere could be awkward.
    def expand_user(user, via_household: false)
      users = (user.child? && !address?(user) && !via_household) ? user.guardians.to_a : [user]
      users.select { |u| reachable?(u) }
    end

    def apply_inactive_rule(recipients)
      inactive, others = recipients.partition { |r| r.is_a?(User) && r.inactive? }
      case kind.include_inactive
      when :always then recipients
      when :if_no_active then others.empty? ? inactive : others
      else others
      end
    end

    # Don't send to fake users, or to unconfirmed full-access users, to be safe.
    # Users without full access can't confirm, but may still want notifications, so they're allowed.
    def reachable?(user)
      address?(user) && !user.fake? && !(user.full_access? && !user.confirmed?)
    end

    # Whether we have somewhere to send this channel's notifications for the user.
    def address?(user)
      case channel
      when :email then user.email.present?
      end
    end
  end
end
