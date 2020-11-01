# frozen_string_literal: true

require "rails_helper"

describe Billing::Template do
  it "has a valid factory" do
    create(:billing_template)
  end
end
