# frozen_string_literal: true

require "rails_helper"

describe Communities::Signup do
  it "upcases country_code on save" do
    signup = create(:communities_signup, country_code: "ca")
    expect(signup.country_code).to eq("CA")
  end
end
