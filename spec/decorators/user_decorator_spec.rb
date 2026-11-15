# frozen_string_literal: true

require "rails_helper"

describe UserDecorator do
  let(:household) { create(:household, unit_num: 12, unit_suffix: "A") }
  let(:user) { create(:user, household: household).decorate }

  it "formats the unit number for the locale" do
    expect(user.formatted_unit_num).to eq("#12-A")
    I18n.with_locale(:de) { expect(user.formatted_unit_num).to eq("Nr. 12-A") }
  end

  it "links the formatted unit number to the household" do
    I18n.with_locale(:de) { expect(user.unit_link).to include(">Nr. 12-A</a>") }
  end

  context "without a unit number" do
    let(:household) { create(:household, unit_num: nil) }

    it "has no unit" do
      expect(user.formatted_unit_num).to be_nil
      expect(user.unit_link).to be_nil
    end
  end
end
