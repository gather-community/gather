# frozen_string_literal: true

require "rails_helper"

describe "email confirmation" do
  # Confirmation emails are re-sent from the user's profile, not Devise's resend form.
  it "doesn't offer Devise's resend form" do
    expect { get(new_user_confirmation_path) }.to raise_error(ActionController::RoutingError)
    expect { post(user_confirmation_path, params: {user: {email: "a@b.com"}}) }
      .to raise_error(ActionController::RoutingError)
  end
end
