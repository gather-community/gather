# frozen_string_literal: true

require "rails_helper"

describe "external super admin", js: true do
  let(:other_cluster) { create(:cluster) }
  let(:outside_community) { ActsAsTenant.with_tenant(other_cluster) { create(:community) } }
  let(:actor) do
    ActsAsTenant.with_tenant(other_cluster) { create(:super_admin, community: outside_community) }
  end

  before do
    use_subdomain(Defaults.community.slug)
    login_as(actor, scope: :user)
  end

  scenario "loads page normally" do
    visit("/users")
    expect(page).to have_content(/Directory/)
  end
end
