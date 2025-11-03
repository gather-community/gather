# frozen_string_literal: true

# == Schema Information
#
# Table name: clusters
#
#  id         :integer          not null, primary key
#  created_at :datetime         not null
#  name       :string(20)       not null
#  sso_secret :string           not null
#  updated_at :datetime         not null
#
# A group of related communities.
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
