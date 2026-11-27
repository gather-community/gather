# frozen_string_literal: true

require "rails_helper"

describe "community settings" do
  let(:actor) { create(:admin) }

  before do
    use_user_subdomain(actor)
    sign_in(actor)
  end

  it "permanently redirects the legacy /admin/settings URL" do
    get("/admin/settings/community")
    expect(response).to have_http_status(:moved_permanently)
    expect(response).to redirect_to("/settings/community")
  end

  it "shows settings at the new URL" do
    get("/settings/community")
    expect(response).to have_http_status(:ok)
  end
end
