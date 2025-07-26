# frozen_string_literal: true

module Utils
  module Generators
    # Generates group samples and a default everybody group.
    class GroupGenerator < Generator
      attr_accessor :community, :users, :user_index

      def initialize(community:)
        self.community = community
        self.users = User.full_access.all
        self.user_index = 0
      end

      def generate_seed_data
        generate_everybody_group
        generate_gather_coop_domain
      end

      def generate_samples
        generate_and_populate_everybody_group
        generate_and_populate_closed_group
        generate_and_populate_open_group
      end

      private

      def generate_everybody_group
        create(:group, communities: [community], availability: "everybody",
                       name: "Full Community", kind: "group",
                       description: "General group containing all full users in the community.")
      end

      def generate_gather_coop_domain
        create(:domain, name: "#{community.slug}.gather.coop", communities: [community])
      end

      def generate_and_populate_everybody_group
        generate_everybody_group unless Groups::Group.where(availability: "everybody").exists?
        group = Groups::Group.find_by(availability: "everybody")
        group.memberships.create!(user: users[user_index], kind: "manager")
        group.memberships.create!(user: users[user_index + 1], kind: "opt_out")
        group.memberships.create!(user: users[user_index + 2], kind: "opt_out")
        self.user_index += 3
      end

      def generate_and_populate_closed_group
        group = create(:group, communities: [community], availability: "closed", name: "Meals Committee",
                               kind: "committee", description: "Runs the meals program!")
        group.memberships.create!(user: users[user_index], kind: "manager")
        group.memberships.create!(user: users[user_index + 1], kind: "joiner")
        group.memberships.create!(user: users[user_index + 2], kind: "joiner")
        group.memberships.create!(user: users[user_index + 3], kind: "joiner")
        self.user_index += 4
      end

      def generate_and_populate_open_group
        group = create(:group, communities: [community], availability: "open",
                               name: "Knitting Club", kind: "club",
                               description: "Knitting for beginners to experts! Meets Sundays at 2pm.")
        group.memberships.create!(user: users[user_index], kind: "manager")
        group.memberships.create!(user: users[user_index + 1], kind: "manager")
        group.memberships.create!(user: users[user_index + 2], kind: "joiner")
        group.memberships.create!(user: users[user_index + 3], kind: "joiner")
        group.memberships.create!(user: users[user_index + 4], kind: "joiner")
        self.user_index += 5
      end
    end
  end
end
