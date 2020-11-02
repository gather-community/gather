# frozen_string_literal: true

require "rails_helper"

describe Billing::Template do
  it "has a valid factory" do
    member_type = create(:member_type)
    create(:billing_template, member_types: [member_type])
  end
end
