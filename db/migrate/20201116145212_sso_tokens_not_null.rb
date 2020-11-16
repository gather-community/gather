# frozen_string_literal: true

class SsoTokensNotNull < ActiveRecord::Migration[6.0]
  def up
    Cluster.where(sso_secret: nil).find_each do |cluster|
      cluster.update!(sso_secret: UniqueTokenGenerator.generate(Cluster, :sso_secret, type: :hex32))
    end
    ActsAsTenant.without_tenant do
      Community.where(sso_secret: nil).find_each do |community|
        community.update!(sso_secret: UniqueTokenGenerator.generate(Community, :sso_secret, type: :hex32))
      end
    end
    change_column_null(:clusters, :sso_secret, false)
    change_column_null(:communities, :sso_secret, false)
  end
end
