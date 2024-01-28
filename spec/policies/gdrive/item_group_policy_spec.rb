# frozen_string_literal: true

require "rails_helper"

describe GDrive::ItemGroupPolicy do
  describe "permissions" do
    include_context "policy permissions"
    let(:item_group) { create(:gdrive_item_group) }
    let(:record) { item_group }

    before do
      expect(FeatureFlag).to receive(:lookup).at_least(:once).and_return(double(on?: true))
    end

    permissions :new?, :create?, :destroy? do
      it_behaves_like "permits admins from community"
    end
  end

  describe "permitted attributes" do
    include_context "policy permissions"
    let(:item) { create(:gdrive_item_group) }
    let(:actor) { admin }

    subject { described_class.new(actor, GDrive::ItemGroup.new).permitted_attributes }

    it do
      expect(subject).to match_array(%i[access_level group_id item_id])
    end
  end
end
