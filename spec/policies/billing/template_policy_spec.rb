# frozen_string_literal: true

require "rails_helper"

describe Billing::TemplatePolicy do
  describe "permissions" do
    include_context "policy permissions"

    let(:record) { create(:billing_template) }

    permissions :index?, :show?, :new?, :edit?, :create?, :update?, :destroy? do
      it_behaves_like "permits admins or special role but not regular users", :biller
    end
  end

  describe "scope" do
    include_context "policy scopes"
    let(:klass) { Billing::Template }
    let!(:objs_in_community) { create_list(:billing_template, 2) }
    let!(:objs_in_cluster) { create_list(:billing_template, 2, community: communityB) }

    it_behaves_like "permits only admins or special role in community", :biller
  end

  describe "permitted attributes" do
    include_context "policy permissions"
    let(:actor) { biller }
    subject { Billing::TemplatePolicy.new(actor, Billing::Template.new).permitted_attributes }

    it do
      expect(subject).to match_array(%i[description code value] << {member_type_ids: []})
    end
  end
end
