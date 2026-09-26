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
    pi = double("Stripe::PaymentIntent", status: "succeeded", next_action: nil, amount: 1800)
    item = stripe_subscription_item_double(
      quantity: 3, current_period_end: 1.month.from_now.to_i,
      price: double(unit_amount: 600, currency: "usd", recurring: double(interval_count: 3),
        product: double(metadata: {"tier" => "standard"}))
    )
    stripe_subscription_double(
      status: "active", pending_setup_intent: nil, discounts: [],
      default_payment_method: default_payment_method, items: [item],
      latest_invoice: stripe_invoice_double(payment_intent: pi),
      customer: double(id: "cus_1", email: "biller@example.com",
        invoice_settings: double(default_payment_method: nil))
    )
  end

  # status/cancel_at_period_end are parameterized because the wind-down and the completed
  # cancellation are the two states the page has to tell apart, and Stripe reports them confusingly:
  # while cancelling the status is still "active", and once canceled cancel_at_period_end flips back
  # to false while the item and price stay readable.
  def fake_topup_sub(amount_cents:, status: "active", cancel_at_period_end: false)
    item = stripe_subscription_item_double(
      id: "si_1", current_period_end: topup_period_end.to_i,
      price: double(unit_amount: amount_cents, currency: "usd")
    )
    stripe_subscription_double(status: status, cancel_at_period_end: cancel_at_period_end,
      latest_invoice: nil, items: [item])
  end

  let(:topup_period_end) { 1.month.from_now }
  let(:topup_status) { "active" }
  let(:topup_canceling) { false }

  before do
    create(:feature_flag, name: "messaging", status: true)
    allow(Stripe::Subscription).to receive(:retrieve) do |args|
      if args[:id].to_s.start_with?("sub_topup")
        fake_topup_sub(amount_cents: 500, status: topup_status,
          cancel_at_period_end: topup_canceling)
      else
        fake_main_sub
      end
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
    stripe_invoice_double(
      id: "in_new", currency: "usd", subscription: sub_id,
      # card paid instantly -> credit synchronously
      payment_intent: double("Stripe::PaymentIntent", status: "succeeded"),
      lines: [stripe_invoice_line_double(id: "il_new", amount: amount, currency: "usd",
        product: product_id)]
    )
  end

  context "when a topup already exists" do
    let!(:topup) { create(:messaging_topup, community: actor.community, stripe_id: "sub_topup1") }

    scenario "changing the amount shows the real prorated charge" do
      allow(Stripe::Price).to receive(:list).and_return(double(data: []))
      allow(Stripe::Price).to receive(:create).and_return(double(id: "price_1"))
      allow(Stripe::Invoice).to receive(:create_preview).and_return(
        stripe_invoice_double(lines: [stripe_invoice_line_double(proration: true, amount: 342)])
      )

      visit(subscription_path)
      expect(page).to have_content("$5.00/month")

      click_link("Edit")
      find("label", text: "$10.00/month").click
      # The notice reflects the Stripe-computed proration, not a hard-coded amount.
      expect(page).to have_content("$3.42 today (prorated)")
      expect(page).to have_content("$10.00 per month")
    end

    scenario "a running topup shows its next payment date and no status" do
      visit(subscription_path)

      expect(page).to have_content("Next Payment Date")
      expect(page).to have_content(I18n.l(topup_period_end.to_date))
      expect(page).to have_no_content("Canceling on")
      expect(page).to have_link("Edit")
    end

    # The wind-down: the community chose None, Stripe keeps the subscription "active" until the
    # paid-through date, and from here no further invoice is generated — so no charge and no credit.
    # The page must not advertise money that will never move.
    context "while a cancellation is pending" do
      let(:topup_canceling) { true }

      scenario "shows None with the wind-down date and no payment date" do
        visit(subscription_path)

        # The chosen amount is None: nothing more will be billed.
        expect(page).to have_content("None")
        expect(page).to have_no_content("$5.00/month")
        # The end date is not a payment date, so only the Status row carries it.
        expect(page).to have_no_content("Next Payment Date")
        expect(page).to have_content("Canceling on #{I18n.l(topup_period_end.to_date)}")
      end

      scenario "the modal preselects None, not the amount winding down" do
        visit(subscription_path)
        click_link("Add")

        expect(page).to have_content("Choose how much messaging credit")
        expect(find("input[name='topup_choice'][value='none']")).to be_checked
        expect(find("input[name='topup_choice'][value='500']")).not_to be_checked

        # Re-picking None changes nothing, so there is nothing to save.
        find("label", text: "None").click
        expect(page).to have_button("Save", disabled: true)
      end

      # Reviving at the existing amount reuses the same Stripe price, so nothing prorates. The copy
      # must not promise a charge today.
      scenario "re-adding the same amount promises no charge today" do
        allow(Stripe::Price).to receive(:list).and_return(double(data: []))
        allow(Stripe::Price).to receive(:create).and_return(double(id: "price_1"))
        allow(Stripe::Invoice).to receive(:create_preview).and_return(
          stripe_invoice_double(lines: [stripe_invoice_line_double(proration: false, amount: 500)])
        )

        visit(subscription_path)
        click_link("Add")
        find("label", text: "$5.00/month").click

        expect(page).to have_content("Starting next billing month you'll be charged $5.00 per month")
        expect(page).to have_no_content("charged $5.00 today")
        expect(page).to have_no_content("(prorated)")
        expect(page).to have_button("Save", disabled: false)
      end

      scenario "re-adding revives the topup rather than repricing a dying one" do
        allow(Stripe::Price).to receive(:list).and_return(double(data: []))
        allow(Stripe::Price).to receive(:create).and_return(double(id: "price_1"))
        allow(Stripe::Invoice).to receive(:create_preview).and_return(
          stripe_invoice_double(lines: [stripe_invoice_line_double(proration: true, amount: 250)])
        )
        allow(Stripe::SubscriptionItem).to receive(:update)
        # The revive: without this the price swap lands on a subscription that is still ending.
        expect(Stripe::Subscription).to receive(:update)
          .with("sub_topup1", cancel_at_period_end: false)

        visit(subscription_path)
        click_link("Add")
        find("label", text: "$10.00/month").click
        expect(page).to have_content("$2.50 today (prorated)")

        click_button("Save")
        expect(page).to have_content("Your monthly messaging topup is set")
      end
    end

    # After Stripe actually cancels, nothing about the payload marks the topup as dead except the
    # status, so a stale row would render as a healthy active topup forever.
    context "once Stripe has completed the cancellation" do
      let(:topup_status) { "canceled" }

      scenario "shows no live topup and clears the stale record" do
        visit(subscription_path)

        expect(page).to have_content("Monthly Topup")
        expect(page).to have_content("None")
        expect(page).to have_no_content("$5.00/month")
        expect(page).to have_no_content("Next Payment Date")
        expect(page).to have_no_content("Canceling on")
        # The Add link is back, because adding now means a brand-new subscription.
        expect(page).to have_link("Add")
        expect(Subscription::MessagingTopup.count).to eq(0)
      end

      scenario "the wallet balance survives the cancellation" do
        account = create(:messaging_account, community: actor.community)
        create(:messaging_transaction, account: account, amount_cents: 1496)

        visit(subscription_path)

        expect(page).to have_content("Current Balance")
        expect(page).to have_content("$14.96")
      end
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
