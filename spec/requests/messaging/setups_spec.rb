# frozen_string_literal: true

require "rails_helper"

# Who can reach texting setup. The flow itself is in spec/system/messaging/setup_spec.rb.
describe "texting setup access" do
  let(:actor) { create(:admin) }
  let(:community) { actor.community }

  before do
    create(:feature_flag, name: "messaging", status: true)
    create(:subscription, community: community, stripe_id: "sub_main1")
    allow(Stripe::Subscription).to receive(:retrieve).and_return(
      stripe_subscription_double(status: "active", pending_setup_intent: nil, discounts: [],
        default_payment_method: "pm_1", latest_invoice: stripe_invoice_double,
        customer: double(id: "cus_1", invoice_settings: double(default_payment_method: nil)))
    )
    use_user_subdomain(actor)
    sign_in(actor)
  end

  it "lets an admin open setup" do
    get(new_messaging_setup_path)
    expect(response).to have_http_status(:ok)
  end

  context "as a regular member" do
    let(:actor) { create(:user) }

    it "refuses the settings page" do
      expect { get(messaging_settings_path) }.to raise_error(Pundit::NotAuthorizedError)
    end

    it "refuses setup" do
      expect { post(messaging_setup_path, params: {messaging_registration: {package_cents: "500"}}) }
        .to raise_error(Pundit::NotAuthorizedError)
    end
  end

  it "refuses setup while the feature flag is off" do
    FeatureFlag.find_by(name: "messaging").update!(status: false)
    expect { get(new_messaging_setup_path) }.to raise_error(Pundit::NotAuthorizedError)
  end

  it "refuses a second setup once one has been paid, so nobody pays twice" do
    create(:messaging_registration, :paid, community: community)
    expect { post(messaging_setup_path, params: {messaging_registration: {package_cents: "500"}}) }
      .to raise_error(Pundit::NotAuthorizedError)
  end

  context "outside the US" do
    before { community.update_column(:country_code, "CA") }

    it "refuses setup" do
      expect { get(new_messaging_setup_path) }.to raise_error(Pundit::NotAuthorizedError)
    end

    it "says why on the settings page" do
      get(messaging_settings_path)
      expect(response.body).to include("only available to communities in the US")
    end
  end
end
