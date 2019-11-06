require "rails_helper"

describe "user impersonation" do
  let(:actor) { create(:admin, first_name: "Lod", last_name: "Prod") }
  let(:impersonatee) { create(:user, first_name: "Flo", last_name: "Flim") }

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  scenario do
    visit user_path(impersonatee)
    click_on("Impersonate")

    expect(page).to have_impersonation_header
    expect(page).to have_signed_in_user(impersonatee)
    click_on_personal_nav("Profile")

    # Header should still be there on next page load.
    expect(page).to have_impersonation_header
    expect(page).to have_title("Flo Flim")

    click_on("Stop Impersonating")
    expect(page).not_to have_impersonation_header
    expect(page).to have_signed_in_user(actor)
  end


  def have_impersonation_header
    have_content("You are impersonating Flo Flim.")
  end
end
