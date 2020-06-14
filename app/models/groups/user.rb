# frozen_string_literal: true

module Groups
  # Wrapper class for User in the context of groups.
  class User
    include ActiveModel::Model

    attr_accessor :user

    # Gets Membership objects for all groups user is a member of. Constructs ephemeral 'joiner' memberships
    # for 'everybody' groups that user is a member of.
    def computed_memberships
      result = Membership.where(user: user).to_a
      all_groups = Group.with_user(user)
      implicit_groups = all_groups - result.map(&:group)
      implicit_groups.each { |g| result << Membership.new(user: user, group: g, kind: "joiner") }
      result
    end
  end
end
