# frozen_string_literal: true

require "rails_helper"

describe People::MemorialPolicy do
  describe "permissions" do
    include_context "policy permissions"
    let(:record) { create(:memorial) }

    permissions :index?, :show?, :contribute? do
      it_behaves_like "permits cluster and super admins"
      it_behaves_like "permits users in cluster"
    end

    permissions :new?, :create?, :edit?, :update?, :destroy? do
      it_behaves_like "permits admins from community"
    end
  end

  describe "scope" do
    include_context "policy scopes"
    let(:klass) { People::Memorial }
    let(:objs_in_community) { create_list(:memorial, 2, user: user) }
    let(:objs_in_cluster) { create_list(:memorial, 2, user: userB) }

    it_behaves_like "permits all users in cluster"
  end

  describe "permitted attributes" do
    include_context "policy permissions"
    let(:actor) { admin }

    subject { described_class.new(actor, People::Memorial.new).permitted_attributes }

    it do
      expect(subject).to match_array(%i[user_id birth_year death_year])
    end
  end
end
