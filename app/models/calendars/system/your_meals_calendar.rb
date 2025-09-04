# frozen_string_literal: true

# == Schema Information
#
# Table name: calendar_nodes
#
#  id                    :integer          not null, primary key
#  abbrv                 :string(6)
#  allow_overlap         :boolean          default(TRUE), not null
#  cluster_id            :integer          not null
#  color                 :string(7)
#  community_id          :integer          not null
#  created_at            :datetime         not null
#  deactivated_at        :datetime
#  default_calendar_view :string           default("week"), not null
#  group_id              :bigint
#  guidelines            :text
#  meal_hostable         :boolean          default(FALSE), not null
#  name                  :string(24)       not null
#  rank                  :integer
#  selected_by_default   :boolean          default(FALSE), not null
#  type                  :string           not null
#  updated_at            :datetime         not null
#
module Calendars
  module System
    # System-populated calendar for all meals in cluser that user has signed up for
    class YourMealsCalendar < MealsCalendar
      protected

      def slug
        # Does not match legacy meal calendar exports
        # This may lead to some duplicates temporarily but there isn't a good alternative.
        "your_meals"
      end

      private

      def hosting_communities
        Community.all
      end

      def base_meals_scope(range, actor:)
        return Meals::Meal.none if actor.nil?
        super.attended_by(actor.household)
      end
    end
  end
end
