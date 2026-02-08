# frozen_string_literal: true

class AddGatherCoopDomainToCmtysWithNoDomains < ActiveRecord::Migration[7.0]
  def up
    Cluster.all.each do |cluster|
      ActsAsTenant.with_tenant(cluster) do
        Community.all.each do |community|
          next if DomainOwnership.where(community: community).any?
          Domain.create!(name: "#{community.slug}.gather.coop", communities: [community])
        end
      end
    end
  end

  def down
  end
end
