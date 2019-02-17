# frozen_string_literal: true

# Holds default objects that get used a lot.
class Defaults
  def self.cluster
    @cluster ||= FactoryBot.create(:cluster, name: "Default")
  end

  def self.community
    @community ||= FactoryBot.create(:community, name: "Default", slug: "default", abbrv: "df")
  end

  # Resets the variables so they will be re-created on next get.
  def self.reset
    @cluster = nil
    @community = nil
  end
end
