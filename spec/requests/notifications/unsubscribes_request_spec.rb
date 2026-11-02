# frozen_string_literal: true

require "rails_helper"

# RFC 8058 one-click unsubscribe: the mail provider POSTs to the List-Unsubscribe URL with no session
# and no CSRF token. This isn't a browser flow, so it's tested here rather than in a system spec.
describe "one-click notification unsubscribe" do
  let(:user) { create(:user) }
  let(:kind) { Notifications::Catalog.find(:meal_reminder) }
  let(:token) { Notifications::Unsubscribe.token_for(user, kind) }

  around do |example|
    # Forgery protection is off in tests by default. Turn it on to show the endpoint works without a token.
    ActionController::Base.allow_forgery_protection = true
    example.run
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  before { use_user_subdomain(user) }

  it "turns the notification off without sign-in or CSRF token" do
    post("/notifications/unsubscribe/#{token}", params: "List-Unsubscribe=One-Click")
    expect(response).to have_http_status(:ok)
    expect(user.reload.notification_enabled?(:meal_reminder)).to be(false)
  end

  it "doesn't change anything on GET" do
    get("/notifications/unsubscribe/#{token}")
    expect(response).to have_http_status(:ok)
    expect(user.reload.notification_enabled?(:meal_reminder)).to be(true)
  end

  it "returns 404 for an invalid token" do
    post("/notifications/unsubscribe/nope", params: "List-Unsubscribe=One-Click")
    expect(response).to have_http_status(:not_found)
  end
end
