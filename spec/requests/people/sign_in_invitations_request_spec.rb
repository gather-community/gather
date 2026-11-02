# frozen_string_literal: true

require "rails_helper"

describe "sign-in invitations" do
  let(:admin) { create(:admin) }

  before do
    use_user_subdomain(admin)
    sign_in(admin)
  end

  # Regression: this used to fall through to an implicit render with no template, returning 204 so the
  # page never changed and the message never showed.
  it "returns to the form with a message when nobody is selected" do
    post(people_sign_in_invitations_path)
    expect(response).to redirect_to(new_people_sign_in_invitation_path)
    follow_redirect!
    expect(response.body).to include("You didn&#39;t select any users.")
  end
end
