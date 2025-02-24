# frozen_string_literal: true

# == Schema Information
#
# Table name: calendar_nodes
#
#  id                    :integer          not null, primary key
#  abbrv                 :string(6)
#  allow_overlap         :boolean          default(TRUE), not null
#  color                 :string(7)
#  deactivated_at        :datetime
#  default_calendar_view :string           default("week"), not null
#  guidelines            :text
#  meal_hostable         :boolean          default(FALSE), not null
#  name                  :string(24)       not null
#  rank                  :integer
#  selected_by_default   :boolean          default(FALSE), not null
#  type                  :string           not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  cluster_id            :integer          not null
#  community_id          :integer          not null
#  group_id              :bigint
#
# Indexes
#
#  index_calendar_nodes_on_cluster_id             (cluster_id)
#  index_calendar_nodes_on_community_id           (community_id)
#  index_calendar_nodes_on_community_id_and_name  (community_id,name) UNIQUE
#  index_calendar_nodes_on_group_id               (group_id)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (community_id => communities.id)
#  fk_rails_...  (group_id => calendar_nodes.id)
#
module Calendars
  module System
    # System-populated calendar for all meals in community
    class CommunityMealsCalendar < MealsCalendar
      protected

      def slug
        # Matches legacy meal calendar exports
        "Meal"
      end

      private

      def hosting_communities
        [community]
      end
    end
  end
end
