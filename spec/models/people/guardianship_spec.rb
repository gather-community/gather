# frozen_string_literal: true

# == Schema Information
#
# Table name: people_guardianships
#
#  id          :integer          not null, primary key
#  child_id    :integer          not null
#  cluster_id  :integer          not null
#  created_at  :datetime         not null
#  guardian_id :integer          not null
#  updated_at  :datetime         not null
#
require "rails_helper"

describe People::Guardianship do
  describe "validations and assertions" do
    context "child user" do
      it "works with one guardian" do
        child = build(:user, :child, guardians: [create(:user)])
        expect(child.valid?).to be(true)
      end

      it "works with two guardians" do
        child = build(:user, :child, guardians: create_list(:user, 2))
        expect(child.valid?).to be(true)
      end

      it "fails with zero guardians" do
        (child = build(:user, :child, guardians: [])).valid?
        expect(child.errors[:up_guardianships]).not_to be_empty
      end
    end

    context "adult user" do
      it "works with children" do
        adult = build(:user, children: create_list(:user, 2, :child))
        expect(adult.valid?).to be(true)
      end

      it "works with no children" do
        adult = build(:user, children: [])
        expect(adult.valid?).to be(true)
      end

      it "raises error if has guardians" do
        expect { create(:user, guardians: [create(:user)]) }.to raise_error(People::AdultWithGuardianError)
      end
    end
  end
end
