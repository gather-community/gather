# frozen_string_literal: true

require "rails_helper"

# The texting setup flow: from the footer, through the setup form and one Stripe charge, to the settings
# page showing the registration under way. Stripe is stubbed at its gem boundary; Telnyx isn't reached,
# because submission happens in a job after the payment settles.
describe "texting setup" do
  let(:actor) { create(:admin) }
  let(:community) { actor.community }
  let!(:subscription) { create(:subscription, community: community, stripe_id: "sub_main1") }
  let(:default_payment_method) { "pm_1" }

  def fake_main_sub
    pi = double("Stripe::PaymentIntent", status: "succeeded", next_action: nil, amount: 1800)
    stripe_subscription_double(
      status: "active", pending_setup_intent: nil, discounts: [],
      default_payment_method: default_payment_method,
      latest_invoice: stripe_invoice_double(payment_intent: pi),
      customer: double(id: "cus_1", email: "admin@example.com",
        invoice_settings: double(default_payment_method: nil))
    )
  end

  def setup_invoice
    product = Messaging::Account::PRODUCT_ID
    stripe_invoice_double(id: "in_setup", currency: "usd", status: "paid", subscription: "sub_topup1",
      payment_intent: double("Stripe::PaymentIntent", status: "succeeded"),
      lines: [
        stripe_invoice_line_double(id: "il_pkg", amount: 1000, currency: "usd", product: product),
        double("Stripe::InvoiceLineItem", id: "il_setup", amount: 2400, currency: "usd",
          pricing: double(price_details: double(product: product, price: "price_x")),
          parent: double(type: "invoice_item_details"))
      ])
  end

  before do
    create(:feature_flag, name: "messaging", status: true)
    allow(Stripe::Subscription).to receive(:retrieve).and_return(fake_main_sub)
    allow(Stripe::Price).to receive(:list).and_return(double(data: []))
    allow(Stripe::Price).to receive(:create).and_return(double(id: "price_1"))
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  def fill_in_organization
    fill_in("Legal name", with: "Sunny Hill Cohousing Association")
    fill_in("Name people know you by", with: "Sunny Hill")
    select("Nonprofit", from: "Type of organization")
    fill_in("EIN", with: "12-3456789")
    fill_in("Street address", with: "1 Main St")
    fill_in("City", with: "Ithaca")
    select("NY", from: "State")
    fill_in("ZIP code", with: "14850")
    fill_in("Contact email", with: "admin@example.com")
    fill_in("Contact phone", with: "607-555-1234")
  end

  it "sets up texting with one payment and shows the registration under way" do
    expect(Stripe::Subscription).to receive(:create)
      .with(hash_including(
        add_invoice_items: [hash_including(price_data: hash_including(unit_amount: 2400))]
      ))
      .and_return(double(id: "sub_topup1", latest_invoice: setup_invoice))

    visit(root_path)
    click_link("Texting", match: :first)
    expect(page).to have_content("It isn't set up yet")
    click_link("Set Up Texting")

    expect(page).to have_content("Setup fee (one time)")
    expect(page).to have_content("$24.00")
    expect(page).not_to have_content("$2.00/month")
    expect(page).to have_content("Reply STOP to opt out") # the sample messages, as they'll be submitted
    choose("$10.00/month", match: :prefer_exact)
    fill_in_organization
    check("I understand the $24.00 setup fee isn't refundable")
    click_button("Set Up and Pay")

    expect(page).to have_content("We're registering your community with the carriers")
    expect(page).to have_content("Submitting")
    expect(page).to have_content("$34.00") # the setup fee and first month, credited
    registration = with_default_tenant { community.reload.messaging_registration }
    expect(registration.paid_at).to be_present
    expect(Messaging::AdvanceRegistrationJob).to have_been_enqueued.with(registration.id)
  end

  it "keeps the details and shows the reason when the card is declined" do
    allow(Stripe::Subscription).to receive(:create)
      .and_raise(Stripe::CardError.new("Your card was declined.", nil))
    visit(new_messaging_setup_path)
    choose("$5.00/month", match: :prefer_exact)
    fill_in_organization
    check("I understand the $24.00 setup fee isn't refundable")
    click_button("Set Up and Pay")

    expect(page).to have_content("Your payment didn't go through: Your card was declined.")
    expect(page).to have_field("Legal name", with: "Sunny Hill Cohousing Association")
  end

  it "explains what's missing when there's no payment method" do
    allow(Stripe::Subscription).to receive(:retrieve).and_return(fake_main_sub.tap { |s|
      allow(s).to receive(:default_payment_method).and_return(nil)
    })
    visit(messaging_settings_path)
    expect(page).to have_content("needs an active Gather subscription with a payment method")
    expect(page).not_to have_link("Set Up Texting")
  end

  context "as a regular member" do
    let(:actor) { create(:user) }

    it "shows no link to texting settings (access is checked in spec/requests/messaging/setups_spec.rb)" do
      visit(root_path)
      expect(page).not_to have_link("Texting")
    end
  end
end
