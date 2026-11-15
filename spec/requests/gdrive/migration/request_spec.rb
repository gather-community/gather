# frozen_string_literal: true

require "rails_helper"

describe "gdrive migration request links" do
  let!(:migration_request) { create(:gdrive_migration_request, created_at: 31.days.ago) }

  before do
    use_subdomain(migration_request.operation.community.slug)
  end

  it "won't let an expired link opt out" do
    patch("/gdrive/migration/request/#{migration_request.token}/confirm-opt-out",
      params: {gdrive_migration_request: {opt_out_reason: "No thanks"}})
    expect(response).to have_http_status(:gone)
    expect(migration_request.reload.status).to eq("new")
  end
end
