# frozen_string_literal: true

require "rails_helper"

describe Groups::Mailman::ListSyncJob do
  include_context "jobs"

  let(:api) { double }
  let(:domain) { create(:domain, name: "tscoho.org") }
  subject(:job) { described_class.new(*job_args) }

  before do
    allow(Groups::Mailman::Api).to receive(:instance).and_return(api)
  end

  context "when list just destroyed" do
    let!(:job_args) do
      [
        list_attribs: {"cluster_id" => ActsAsTenant.current_tenant.id, "remote_id" => "ping.tscoho.org"},
        destroyed: true
      ]
    end

    it "deletes list" do
      expect(api).to receive(:delete_list, &with_obj_attribs(remote_id: "ping.tscoho.org"))
      expect { perform_job }.not_to have_enqueued_job(Groups::Mailman::MembershipSyncJob)
    end
  end

  context "when list not just destroyed" do
    let(:list) { create(:group_mailman_list, name: "foo", domain: domain, remote_id: initial_remote_id) }
    let!(:job_args) { [list_id: list.id] }

    context "when remote list doesn't exist" do
      let(:initial_remote_id) { nil }

      it "creates and configures list with full settings and enqueues list membership update" do
        expect(api).to receive(:create_domain, &with_obj_attribs(name: "tscoho.org")).ordered
        expect(api).to receive(:create_list, &with_obj_attribs(fqdn_listname: "foo@tscoho.org")).ordered
          .and_return("a1b2c3")
        expect(api).to receive(:configure_list,
                               &with_obj_attribs(fqdn_listname: "foo@tscoho.org",
                                                 config: Groups::Mailman::List::DEFAULT_SETTINGS)).ordered
        expect { perform_job }.to have_enqueued_job(Groups::Mailman::MembershipSyncJob)
          .with("Groups::Mailman::List", list.id)
        expect(list.reload.remote_id).to eq("a1b2c3")
      end
    end

    context "when remote list exists" do
      let(:initial_remote_id) { "bbccdd" }

      it "configures list with sticky settings and enqueues list membership update" do
        expect(api).to receive(:create_domain, &with_obj_attribs(name: "tscoho.org")).ordered
        expect(api).to receive(:create_list, &with_obj_attribs(fqdn_listname: "foo@tscoho.org"))
          .and_return(nil).ordered
        expected_config = Groups::Mailman::List::DEFAULT_SETTINGS
          .slice(*Groups::Mailman::List::ENFORCED_SETTINGS)
        expect(expected_config).to be_instance_of(Hash)
        expect(expected_config.size).to eq(Groups::Mailman::List::ENFORCED_SETTINGS.size)
        expect(api).to receive(:configure_list,
                               &with_obj_attribs(fqdn_listname: "foo@tscoho.org",
                                                 config: expected_config)).ordered
        expect { perform_job }.to have_enqueued_job(Groups::Mailman::MembershipSyncJob)
          .with("Groups::Mailman::List", list.id)
        expect(list.reload.remote_id).to eq("bbccdd")
      end
    end
  end
end
