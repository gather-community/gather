# frozen_string_literal: true

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
