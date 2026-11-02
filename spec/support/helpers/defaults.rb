# frozen_string_literal: true

# Holds default objects that get used a lot.
class Defaults
  def self.cluster
    @cluster ||= FactoryBot.create(:cluster, name: "Default")
  end

  def self.community
    # Factories use this community when none is given. Inside `with_tenant` for some other cluster, it
    # must be a community in that cluster, or ActsAsTenant rejects the record's community association.
    tenant = ActsAsTenant.current_tenant
    if tenant.nil? || tenant == cluster
      # If this causes a uniqueness error, it may be because there is an error in the test and then a
      # second error, and the transaction is not getting properly rolled back.
      @community ||= FactoryBot.create(:community, name: "Default", slug: "default", abbrv: "df")
    else
      @other_communities ||= {}
      @other_communities[tenant.id] ||= Community.order(:id).first || FactoryBot.create(:community)
    end
  end

  # Resets the variables so they will be re-created on next get.
  def self.reset
    @cluster = nil
    @community = nil
    @other_communities = nil
  end
end
