# frozen_string_literal: true

# == Schema Information
#
# Table name: group_affiliations
#
#  id           :bigint           not null, primary key
#  cluster_id   :bigint           not null
#  community_id :bigint           not null
#  group_id     :bigint           not null
#
module Groups
  # An affiliation of a group to a community. A join model.
  class Affiliation < ApplicationRecord
    include Wisper.model

    acts_as_tenant :cluster

    belongs_to :group, inverse_of: :affiliations
    belongs_to :community, inverse_of: :group_affiliations
  end
end
