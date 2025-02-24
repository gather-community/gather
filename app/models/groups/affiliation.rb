# frozen_string_literal: true

module Groups
# == Schema Information
#
# Table name: group_affiliations
#
#  id           :bigint           not null, primary key
#  cluster_id   :bigint           not null
#  community_id :bigint           not null
#  group_id     :bigint           not null
#
# Indexes
#
#  index_group_affiliations_on_cluster_id                 (cluster_id)
#  index_group_affiliations_on_community_id               (community_id)
#  index_group_affiliations_on_community_id_and_group_id  (community_id,group_id) UNIQUE
#  index_group_affiliations_on_group_id                   (group_id)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (community_id => communities.id)
#  fk_rails_...  (group_id => groups.id)
#
  # An affiliation of a group to a community. A join model.
  class Affiliation < ApplicationRecord
    include Wisper.model

    acts_as_tenant :cluster

    belongs_to :group, inverse_of: :affiliations
    belongs_to :community, inverse_of: :group_affiliations
  end
end
