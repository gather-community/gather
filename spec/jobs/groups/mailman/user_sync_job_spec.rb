# frozen_string_literal: true

require "rails_helper"

describe Groups::Mailman::UserSyncJob do
  include_context "jobs"

  let(:api) { double }

  before do
    allow(Groups::Mailman::Api).to receive(:instance).and_return(api)
  end

  context "when user still exists" do
    let(:user) { create(:user, first_name: "John", last_name: "Bing") }
    subject(:job) { described_class.new(user_id: user.id) }

    context "with matching local mailman user record" do
      let!(:mailman_user) { create(:group_mailman_user, user: user, remote_id: "abcd") }
      let(:remote_user_exists) { true }

      before do
        expect(job).to receive(:find_mailman_user).and_return(mailman_user)
        expect(mailman_user).to receive(:syncable_with_memberships?).and_return(syncable_with_memberships)
      end

      context "when user is syncable" do
        let(:syncable_with_memberships) { true }

        before do
          expect(api).to receive(:user_exists?, &with_obj_attribs(remote_id: "abcd"))
            .and_return(remote_user_exists)
        end

        context "with valid mailman ID" do
          it "syncs user info and enqueues membership sync" do
            expect(api).to receive(:update_user,
                                   &with_obj_attribs(remote_id: "abcd", display_name: "John Bing",
                                                     email: user.email))
            expect { perform_job }.to have_enqueued_job(Groups::Mailman::MembershipSyncJob)
              .with("Groups::Mailman::User", mailman_user.id)
          end
        end

        context "with mailman ID not found" do
          let(:remote_user_exists) { false }

          it "deletes mailman_user record and re-enqueues job" do
            expect { perform_job }.to have_enqueued_job(described_class).with(user.id)
            expect { mailman_user.reload }.to raise_error(ActiveRecord::RecordNotFound)
          end
        end
      end

      context "when user is not syncable_with_memberships" do
        let(:syncable_with_memberships) { false }

        it "deletes remote user" do
          expect(api).to receive(:delete_user, &with_obj_attribs(remote_id: "abcd"))
          expect { perform_job }.not_to have_enqueued_job
        end
      end
    end

    context "without matching local mailman user record" do
      let(:mailman_user) { Groups::Mailman::User.new(user: user) }

      before do
        expect(job).to receive(:build_mailman_user).with({user: user}).and_return(mailman_user)
        expect(mailman_user).to receive(:syncable_with_memberships?).and_return(syncable_with_memberships)
      end

      context "when user is syncable_with_memberships" do
        let(:syncable_with_memberships) { true }

        context "with matching email on mailman side" do
          before do
            expect(api).to receive(:user_id_for_email, &with_obj_attribs(email: user.email))
              .and_return("abcd")
          end

          context "if returned mm ID exists in local DB" do
            let!(:duplicate_mm_user) { create(:group_mailman_user, remote_id: "abcd") }

            it "raises error" do
              expect { perform_job }.to raise_error(Groups::Mailman::SyncJob::SyncError)
            end
          end

          context "normal case" do
            it "saves and updates user and enqueues job" do
              expect(api).to receive(:update_user,
                                     &with_obj_attribs(remote_id: "abcd", display_name: "John Bing",
                                                       email: user.email))
              expect { perform_job }
                .to have_enqueued_job(Groups::Mailman::MembershipSyncJob)
              expect(mailman_user).to be_persisted
              expect(mailman_user.remote_id).to eq("abcd")
            end
          end
        end

        context "with no matching email on mailman side" do
          before do
            expect(api).to receive(:user_id_for_email, &with_obj_attribs(email: user.email)).and_return(nil)
          end

          it "creates mm user and enqueues membership sync" do
            expect(api).to receive(:create_user,
                                   &with_obj_attribs(display_name: "John Bing", email: user.email))
              .and_return("abcd")
            expect { perform_job }
              .to have_enqueued_job(Groups::Mailman::MembershipSyncJob)
            mm_user = Groups::Mailman::User.find_by(user: user)
            expect(mm_user.remote_id).to eq("abcd")
          end
        end
      end

      context "when user is not syncable_with_memberships" do
        let(:syncable_with_memberships) { false }

        context "with matching email on mailman side" do
          before do
            expect(api).to receive(:user_id_for_email, &with_obj_attribs(email: user.email))
              .and_return("abcd")
          end

          it "deletes remote user" do
            expect(api).to receive(:delete_user, &with_obj_attribs(remote_id: "abcd"))
            expect { perform_job }.not_to have_enqueued_job
          end
        end

        context "with no matching email on mailman side" do
          before do
            expect(api).to receive(:user_id_for_email, &with_obj_attribs(email: user.email)).and_return(nil)
          end

          it "does nothing" do
            expect(api).not_to receive(:delete_user)
            expect { perform_job }.not_to have_enqueued_job
          end
        end
      end
    end
  end

  context "When user was just destroyed" do
    let(:cluster_id) { ActsAsTenant.current_tenant.id }
    subject!(:job) do
      described_class.new(mm_user_attribs: {remote_id: "ab12cd", cluster_id: cluster_id},
                          destroyed: true)
    end

    it "calls delete_user" do
      expect(api).to receive(:delete_user, &with_obj_attribs(remote_id: "ab12cd"))
      expect { perform_job }.not_to have_enqueued_job
    end
  end
end
