# frozen_string_literal: true

require "rails_helper"

describe GDrive::Migration::OperationPolicy do
  describe "permissions" do
    include_context "policy permissions"
    let(:operation) { create(:gdrive_migration_operation, community: community) }
    let(:record) { operation }

    permissions :show?, :new?, :create?, :edit?, :rescan?, :update?, :destroy? do
      it_behaves_like "permits admins from community"
    end
  end

  describe "permitted attributes" do
    include_context "policy permissions"
    let(:actor) { admin }

    subject { described_class.new(actor, GDrive::Migration::Operation.new).permitted_attributes(action) }

    context "create" do
      let(:action) { :create }

      it do
        expect(subject).to match_array(%i[contact_email contact_name dest_folder_id src_folder_id])
      end
    end

    context "update" do
      let(:action) { :update }

      it do
        expect(subject).to match_array(%i[contact_email contact_name])
      end
    end
  end
end
