# frozen_string_literal: true

require "rails_helper"

describe "community signups", js: true do
  let(:approver) do
    user = create(:user)
    user.add_role(:new_community_approver)
    user
  end

  before do
    use_apex_domain
  end

  describe "public signup flow" do
    before do
      allow_any_instance_of(Communities::SignupsController).to receive(:verify_hcaptcha).and_return(true)
    end

    scenario "submit valid application" do
      visit(new_communities_signup_path)
      expect(page).to have_title("Joining Gather!")

      fill_in("First Name", with: "Alice")
      fill_in("Last Name", with: "Smith")
      fill_in("Email Address", with: "alice@example.com")
      fill_in("Community Name", with: "Sunrise Cohousing")
      fill_in("URL Slug", with: "sunrise-coho")
      select("United States", from: "Country")
      select("Eastern Time (US & Canada)", from: "Time Zone")
      fill_in("About Your Community", with: "We are a cohousing community. https://sunrise.example.com")

      emails = email_sent_by do
        click_button("Submit Application")
        expect(page).to have_title("Application Submitted")
      end

      expect(page).to have_content("alice@example.com")
      expect(Communities::Signup.last.community_name).to eq("Sunrise Cohousing")
    end

    scenario "shows validation errors for missing fields" do
      visit(new_communities_signup_path)
      click_button("Submit Application")
      expect(page).to have_css(".form-group.has-error")
      expect(page).to have_css(".error", text: "can't be blank")
    end

    scenario "shows validation error for invalid slug format" do
      visit(new_communities_signup_path)
      fill_in("First Name", with: "Alice")
      fill_in("Last Name", with: "Smith")
      fill_in("Email Address", with: "alice@example.com")
      fill_in("Community Name", with: "Test")
      fill_in("URL Slug", with: "INVALID SLUG!")
      select("United States", from: "Country")
      select("Eastern Time (US & Canada)", from: "Time Zone")
      fill_in("About Your Community", with: "Test community https://example.com")
      click_button("Submit Application")
      expect(page).to have_css(".error", text: "only lowercase")
    end
  end

  describe "captcha failure" do
    before do
      allow_any_instance_of(Communities::SignupsController).to receive(:verify_hcaptcha).and_return(false)
    end

    scenario "re-renders form when captcha fails" do
      visit(new_communities_signup_path)
      fill_in("First Name", with: "Alice")
      fill_in("Last Name", with: "Smith")
      fill_in("Email Address", with: "alice@example.com")
      fill_in("Community Name", with: "Test")
      fill_in("URL Slug", with: "test-slug")
      select("United States", from: "Country")
      select("Eastern Time (US & Canada)", from: "Time Zone")
      fill_in("About Your Community", with: "Test https://example.com")
      click_button("Submit Application")
      expect(page).to have_title("Joining Gather!")
      expect(page).to have_css(".error", text: "Captcha")
      expect(Communities::Signup.count).to eq(0)
    end
  end

  describe "approver index" do
    let!(:pending_signup) { create(:communities_signup) }
    let!(:approved_signup) { create(:communities_signup, :approved) }

    before do
      login_as(approver, scope: :user)
      use_user_subdomain(approver)
    end

    scenario "shows pending applications by default" do
      visit(communities_signups_path)
      expect(page).to have_title("Community Signup Applications")
      expect(page).to have_content(pending_signup.community_name)
      expect(page).not_to have_content(approved_signup.community_name)
    end

    scenario "can switch to show all applications" do
      visit(communities_signups_path)
      select_lens(:status, "All")
      expect(page).to have_content(pending_signup.community_name)
      expect(page).to have_content(approved_signup.community_name)
    end
  end

  describe "review and approve" do
    let!(:signup) { create(:communities_signup) }

    before do
      login_as(approver, scope: :user)
      use_user_subdomain(approver)
    end

    scenario "approve application", perform_jobs: true do
      visit(review_communities_signup_path(signup))
      expect(page).to have_content(signup.community_name)
      expect(page).to have_content(signup.contact_name)

      email_sent_by do
        select("Approve", from: "Action")
        fill_in("Approval Message", with: "Welcome! We're thrilled to have you join Gather.")
        click_button("Submit")
        expect(page).to have_alert(/approved/)
      end

      signup.reload
      expect(signup).to be_created
      expect(signup.reviewed_by).to eq(approver)
      expect(signup.message).to eq("Welcome! We're thrilled to have you join Gather.")

      new_cluster = ActsAsTenant.without_tenant { Cluster.find_by(name: signup.community_name) }
      expect(new_cluster).to be_present
      ActsAsTenant.with_tenant(new_cluster) do
        community = Community.find_by(name: signup.community_name)
        expect(community).to be_present
        expect(community.slug).to eq(signup.slug)
      end
    end

    scenario "deny application" do
      visit(review_communities_signup_path(signup))

      emails = email_sent_by do
        select("Deny", from: "Action")
        fill_in("Denial Reason (not sent to user)", with: "Does not meet criteria")
        click_button("Submit")
        expect(page).to have_alert(/denied/)
      end

      signup.reload
      expect(signup).to be_denied
      expect(signup.message).to eq("Does not meet criteria")
      expect(emails.map(&:subject)).to include(match(/Regarding your Gather community application/))
    end
  end

  describe "access control" do
    let(:plain_admin) { create(:admin) }

    before do
      login_as(plain_admin, scope: :user)
      use_user_subdomain(plain_admin)
    end

    # Pundit raises NotAuthorizedError which propagates through Puma since
    # show_exceptions=false in test mode. Use raise_server_errors: false so the
    # stored server error doesn't interfere, and verify the page is not accessible.
    scenario "plain admin cannot access signups index", raise_server_errors: false do
      visit(communities_signups_path)
      expect(page).not_to have_title("Community Signup Applications")
    end
  end

  describe "role visibility" do
    context "as super_admin" do
      let(:super_admin) { create(:super_admin) }
      let(:target_user) { create(:user) }

      before do
        login_as(super_admin, scope: :user)
        use_user_subdomain(super_admin)
      end

      scenario "can see new_community_approver checkbox" do
        visit(edit_user_path(target_user))
        expect(page).to have_content("New Community Approver")
      end
    end

    context "as plain admin" do
      let(:admin) { create(:admin) }
      let(:target_user) { create(:user) }

      before do
        login_as(admin, scope: :user)
        use_user_subdomain(admin)
      end

      scenario "cannot see new_community_approver checkbox" do
        visit(edit_user_path(target_user))
        expect(page).not_to have_content("New Community Approver")
      end
    end
  end
end
