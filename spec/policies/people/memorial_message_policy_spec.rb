# frozen_string_literal: true

require "rails_helper"

describe People::MemorialMessagePolicy do
  describe "permissions" do
    include_context "policy permissions"
    let(:record) { create(:memorial_message) }

    permissions :index?, :show?, :new?, :create? do
      it_behaves_like "permits users in cluster"
    end

    permissions :edit?, :update?, :destroy? do
      it_behaves_like "permits admins from community"
      it_behaves_like "forbids regular users"

      it "permits author" do
        expect(subject).to permit(record.author, record)
      end
    end
  end

  describe "scope" do
    include_context "policy scopes"
    let(:klass) { People::MemorialMessage }
    let(:objs_in_community) { create_list(:memorial_message, 2, author: user) }
    let(:objs_in_cluster) { create_list(:memorial_message, 2, author: userB) }

    it_behaves_like "permits all users in cluster"
  end

  describe "permitted attributes" do
    include_context "policy permissions"
    let(:actor) { user }

    subject { described_class.new(actor, People::MemorialMessage.new).permitted_attributes }

    it do
      expect(subject).to match_array(%i[body])
    end
  end
end
