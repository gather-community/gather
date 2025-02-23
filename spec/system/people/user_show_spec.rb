# frozen_string_literal: true

require "rails_helper"

describe "user show" do
  let(:actor) { create(:user) }

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  context "with past meals" do
    let(:user) { create(:user) }
    let!(:meal) do
      create(:meal, :with_menu, title: "Foodz", head_cook: user, served_at: Time.current - 4.months)
    end

    scenario do
      visit(user_path(user))
      expect(page).to have_title(user.decorate.full_name)
      expect(page).to have_content(user.email)
      expect(page).to have_content("Past Head Cook Meals")
      expect(page).to have_content("Foodz")
    end
  end

  # See the User class for more documentation on email confirmation.
  context "pending reconfirmation" do
    let(:actor) { create(:user, :pending_reconfirmation) }

    scenario "clicking resend instructions link" do
      visit(user_path(actor))
      emails = email_sent_by do
        click_link("Resend confirmation instructions")
        expect(page).to have_alert("Instructions sent.")
      end
      expect(emails.map(&:subject)).to eq(["Please Confirm Your Email Address"])
    end

    scenario "clicking resend instructions link" do
      original_email = actor.email
      visit(user_path(actor))
      click_link("Cancel change")
      expect(page).to have_alert("Email change canceled.")
      expect(actor.reload.unconfirmed_email).to be_nil
      expect(actor.email).to eq(original_email)
    end
  end

  context "with custom data" do
    let(:community_with_user_custom_fields) do
      create(:community, settings: {
        people: {
          user_custom_fields_spec: "- key: alpha\n  " \
                                   "type: boolean\n" \
                                   "- key: bravo\n  " \
                                   "type: markdown\n" \
                                   "- key: charlie\n  " \
                                   "type: url\n" \
                                   "- key: delta\n  " \
                                   "type: text\n    " \
                                   "label: Some Long Text"
        }
      })
    end
    let!(:user) do
      create(:user, community: community_with_user_custom_fields,
                    custom_data: {
                      alpha: true,
                      bravo: "**Bold text**",
                      charlie: "https://example.com",
                      delta: "First line\nSecond line"
                    })
    end
    let!(:actor) { create(:user, community: community_with_user_custom_fields) }

    scenario "shows custom data" do
      visit(user_path(user))
      expect(page).to have_content(/Alpha\s+Yes/)
      expect(page).to have_content(/Bravo\s+Bold text/)
      expect(page).to have_css("strong", text: "Bold text")
      expect(page).to have_content(%r{Charlie\s+https://example.com})
      expect(page).to have_link(nil, href: "https://example.com")
      expect(page).to have_content(/Some Long Text\s+First line/)
      expect(page).to have_css("p", text: "First line")
      expect(page).to have_css("p", text: "Second line")
    end
  end
end
