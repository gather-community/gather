# frozen_string_literal: true

require "rails_helper"

# Exercises the Messaging section + monthly topup modal on the subscription page. Stripe is stubbed
# at the Stripe::Subscription boundary so the page renders without live API calls.
describe "messaging monthly topup", js: true do
  let(:actor) { create(:biller) }
  let!(:subscription) { create(:subscription, community: actor.community, stripe_id: "sub_main1") }
  let(:default_payment_method) { "pm_1" }

  # A fully-populated fake base subscription — enough for the show page + messaging_topup_editable?.
  def fake_main_sub
    double("Stripe::Subscription",
      status: "active",
      latest_invoice: double(payment_intent: double(status: "succeeded", next_action: nil, amount: 1800)),
      pending_setup_intent: nil,
      current_period_end: 1.month.from_now.to_i,
      discount: nil,
      default_payment_method: default_payment_method,
      customer: double(id: "cus_1", email: "biller@example.com",
        invoice_settings: double(default_payment_method: nil)),
      items: double(data: [double(quantity: 3,
        price: double(unit_amount: 600, currency: "usd", recurring: double(interval_count: 3),
          product: double(metadata: {"tier" => "standard"})))]))
  end

  def fake_topup_sub(amount_cents:)
    double("Stripe::Subscription",
      status: "active", cancel_at_period_end: false, current_period_end: 1.month.from_now.to_i,
      latest_invoice: nil,
      items: double(data: [double(id: "si_1",
        price: double(unit_amount: amount_cents, currency: "usd"))]))
  end

  before do
    create(:feature_flag, name: "messaging", status: true)
    allow(Stripe::Subscription).to receive(:retrieve) do |args|
      args[:id].to_s.start_with?("sub_topup") ? fake_topup_sub(amount_cents: 500) : fake_main_sub
    end
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  scenario "adding a monthly topup from None" do
    # Stub the Stripe writes the save performs. The created subscription returns a finalized invoice
    # so the controller can credit the wallet synchronously.
    allow(Stripe::Price).to receive(:list).and_return(double(data: []))
    allow(Stripe::Price).to receive(:create).and_return(double(id: "price_1"))
    allow(Stripe::Subscription).to receive(:create).and_return(
      double(id: "sub_topup_new", latest_invoice: fake_finalized_invoice("sub_topup_new", 500))
    )

    visit(subscription_path)

    # Two sections, with the renamed tier row and a None topup.
    expect(page).to have_content("App Subscription")
    expect(page).to have_content("Messaging")
    expect(page).to have_content("/month/user")
    expect(page).to have_content("Current Balance")
    expect(page).to have_content("Monthly Topup")
    expect(page).to have_content("None")

    click_link("Add")
    expect(page).to have_content("Choose how much messaging credit")

    find("label", text: "$5.00/month").click
    expect(page).to have_content("charged $5.00 today for a full month")

    click_button("Save")

    # Reloads to the green success flash with the wallet already credited synchronously.
    expect(page).to have_content("Your monthly messaging topup is set")
    expect(page).to have_content("$5.00/month")
    expect(page).to have_css(".alert-success")
  end

  # A finalized invoice carrying one messaging-product line, as the credit path reads it.
  def fake_finalized_invoice(sub_id, amount)
    product_id = Settings.stripe.messaging.topup_product_id
    double("invoice", id: "in_new", subscription: sub_id, currency: "usd",
      payment_intent: double(status: "succeeded"), # card paid instantly -> credit synchronously
      lines: double(data: [double(id: "il_new", amount: amount, currency: "usd",
        price: double(product: product_id))]))
  end

  context "when a topup already exists" do
    let!(:topup) { create(:messaging_topup, community: actor.community, stripe_id: "sub_topup1") }

    scenario "changing the amount shows the real prorated charge" do
      allow(Stripe::Price).to receive(:list).and_return(double(data: []))
      allow(Stripe::Price).to receive(:create).and_return(double(id: "price_1"))
      allow(Stripe::Invoice).to receive(:upcoming).and_return(
        double(lines: double(data: [double(proration: true, amount: 342)]))
      )

      visit(subscription_path)
      expect(page).to have_content("$5.00/month")

      click_link("Edit")
      find("label", text: "$10.00/month").click
      # The notice reflects the Stripe-computed proration, not a hard-coded amount.
      expect(page).to have_content("$3.42 today (prorated)")
      expect(page).to have_content("$10.00 per month")
    end
  end

  context "when the base subscription has no saved payment method" do
    let(:default_payment_method) { nil }

    scenario "the topup is not editable" do
      visit(subscription_path)
      expect(page).to have_content("None")
      expect(page).to have_no_link("Add")
    end
  end

  context "with the messaging feature flag off" do
    before { FeatureFlag.find_by(name: "messaging").update!(status: false) }

    scenario "the Messaging section is hidden entirely" do
      visit(subscription_path)
      expect(page).to have_content("App Subscription") # page still renders
      expect(page).to have_no_content("Monthly Topup")
      expect(page).to have_no_content("Current Balance")
    end
  end
end
