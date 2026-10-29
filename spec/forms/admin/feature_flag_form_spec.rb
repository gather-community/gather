# frozen_string_literal: true

require "rails_helper"

describe Admin::FeatureFlagForm do
  def build_form(params)
    described_class.new(params: ActionController::Parameters.new(params))
  end

  it "creates a flag in the chosen mode, normalizing the name" do
    form = build_form(name: "  New_Thing ", mode: "everyone")
    expect(form.save).to be(true)
    expect(form.flag.reload.name).to eq("new_thing")
    expect(form.flag.mode).to eq(:everyone)
  end

  it "requires a name" do
    form = build_form(name: " ", mode: "off")
    expect(form.save).to be(false)
    expect(form.errors[:name]).to eq(["can't be blank"])
  end

  it "rejects names that don't look like identifiers" do
    %w[1abc has-dash has\ space _leading].each do |name|
      form = build_form(name: name, mode: "off")
      expect(form).not_to be_valid, "expected #{name.inspect} to be invalid"
      expect(form.errors[:name]).to eq(["must start with a lowercase letter and contain only " \
        "lowercase letters, numbers and underscores"])
    end
  end

  it "rejects names that are too long" do
    form = build_form(name: "a" * (FeatureFlag::NAME_MAX_LENGTH + 1), mode: "off")
    expect(form).not_to be_valid
    expect(form.errors[:name].first).to match(/too long/)
  end

  it "rejects duplicate names" do
    create(:feature_flag, name: "messaging")
    form = build_form(name: "Messaging", mode: "off")
    expect(form.save).to be(false)
    expect(form.errors[:name]).to eq(["has already been taken"])
  end

  it "defaults to off" do
    expect(described_class.new.mode).to eq(:off)
  end
end
