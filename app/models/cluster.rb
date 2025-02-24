# frozen_string_literal: true

# A group of related communities.
# == Schema Information
#
# Table name: clusters
#
#  id         :integer          not null, primary key
#  name       :string(20)       not null
#  sso_secret :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_clusters_on_name  (name)
#
class Cluster < ApplicationRecord
  has_many :communities, inverse_of: :cluster, dependent: :destroy

  before_create :generate_sso_secret

  def multi_community?
    communities.count > 1
  end

  private

  def generate_sso_secret
    self.sso_secret = UniqueTokenGenerator.generate(self.class, :sso_secret, type: :hex32)
  end
end
