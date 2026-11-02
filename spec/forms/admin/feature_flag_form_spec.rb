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

  describe "selected users" do
    let(:jane) { create(:user) }
    let(:bob) { create(:user) }
    let(:carol) { create(:user) }
    let(:flag) { create(:feature_flag, name: "messaging", interface: "user", users: [jane, bob]) }

    def update(params)
      described_class.new(flag: flag, params: ActionController::Parameters.new(params),
        permitted: Admin::FeatureFlagPolicy.new(create(:super_admin), nil).permitted_attributes_for_update)
    end

    it "loads the flag's current users" do
      expect(described_class.new(flag: flag).users).to contain_exactly(jane, bob)
    end

    it "adds and removes users in one save" do
      # The blank entry is what the form always sends, so an emptied list still arrives.
      expect(update(mode: "selected_users", user_ids: ["", bob.id.to_s, carol.id.to_s]).save).to be(true)
      expect(flag.reload.users).to contain_exactly(bob, carol)
    end

    it "removes every user when the list is emptied" do
      update(mode: "selected_users", user_ids: [""]).save
      expect(flag.reload.users).to be_empty
      expect(flag.mode).to eq(:selected_users)
    end

    it "ignores IDs of users that don't exist" do
      update(mode: "selected_users", user_ids: [jane.id.to_s, "0"]).save
      expect(flag.reload.users).to eq([jane])
    end

    it "keeps the users when the list isn't sent at all" do
      update(mode: "selected_users").save
      expect(flag.reload.users).to contain_exactly(jane, bob)
    end

    %w[off everyone].each do |mode|
      it "deletes the users when saved as #{mode}, even if some were sent" do
        update(mode: mode, user_ids: ["", jane.id.to_s, carol.id.to_s]).save
        expect(flag.reload.users).to be_empty
        expect(flag.mode).to eq(mode.to_sym)
      end
    end

    it "creates a flag with users" do
      form = build_form(name: "beta", mode: "selected_users", user_ids: ["", jane.id.to_s])
      expect(form.save).to be(true)
      expect(form.flag.reload.users).to eq([jane])
    end
  end
end
