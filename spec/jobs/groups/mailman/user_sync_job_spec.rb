# frozen_string_literal: true

require "rails_helper"

describe Groups::Mailman::UserSyncJob do
  include_context "jobs"

  let(:user) { create(:user) }
  let(:api) { double }

  before do
    allow(Groups::Mailman::Api).to receive(:instance).and_return(api)
  end

  context "with matching local mailman user record" do
    let!(:mailman_user) { create(:group_mailman_user, user: user, mailman_id: "abcd") }
    let(:remote_user_exists) { true }

    before do
      # Need to stub this so we are returning same instance as here, which we are stubbing stuff on.
      expect(Groups::Mailman::User).to receive(:find_by).and_return(mailman_user)
      expect(mailman_user).to receive(:syncable?).and_return(syncable)
    end

    context "when user is syncable" do
      let(:syncable) { true }

      before do
        expect(api).to receive(:user_exists?).with(id: "abcd").and_return(remote_user_exists)
      end

      context "with valid mailman ID" do
        it "syncs user info and enqueues membership sync" do
          expect(api).to receive(:update_user).with(id: "abcd", first_name: user.first_name,
                                                    last_name: user.last_name, email: user.email)
          expect { perform_job(user) }.to have_enqueued_job(Groups::Mailman::UserMembershipSyncJob)
            .with(mailman_user)
        end
      end

      context "with mailman ID not found" do
        let(:remote_user_exists) { false }

        it "deletes mailman_user record and re-enqueues job" do
          expect { perform_job(user) }.to have_enqueued_job(described_class).with(user)
          expect { mailman_user.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end

    context "when user is not syncable" do
      let(:syncable) { false }

      it "deletes remote user" do
        expect(api).to receive(:delete_user).with(id: "abcd")
        expect { perform_job(user) }.not_to have_enqueued_job
      end
    end
  end

  context "without matching local mailman user record" do
    let(:mailman_user) { Groups::Mailman::User.new(user: user) }

    before do
      allow(Groups::Mailman::User).to receive(:new).and_return(mailman_user)
      expect(mailman_user).to receive(:syncable?).and_return(syncable)
    end

    context "when user is syncable" do
      let(:syncable) { true }

      context "with matching email on mailman side" do
        before do
          expect(api).to receive(:find_user_id).with(email: user.email).and_return("abcd")
        end

        context "if returned mm ID exists in local DB" do
          let!(:duplicate_mm_user) { create(:group_mailman_user, mailman_id: "abcd") }

          it "raises error" do
            expect { perform_job(user) }.to raise_error(Groups::Mailman::SyncJob::SyncError)
          end
        end

        context "normal case" do
          it "saves and updates user and enqueues job" do
            expect(api).to receive(:update_user).with(id: "abcd", first_name: user.first_name,
                                                      last_name: user.last_name, email: user.email)
            expect { perform_job(user) }
              .to have_enqueued_job(Groups::Mailman::UserMembershipSyncJob).with(mailman_user)
            expect(mailman_user).to be_persisted
            expect(mailman_user.mailman_id).to eq("abcd")
          end
        end
      end

      context "with no matching email on mailman side" do
        before do
          expect(api).to receive(:find_user_id).with(email: user.email).and_return(nil)
        end

        it "creates mm user and enqueues membership sync" do
          expect(api).to receive(:create_user)
            .with(first_name: user.first_name, last_name: user.last_name, email: user.email)
            .and_return("abcd")
          expect { perform_job(user) }
            .to have_enqueued_job(Groups::Mailman::UserMembershipSyncJob).with(mailman_user)
          mm_user = Groups::Mailman::User.find_by(user: user)
          expect(mm_user.mailman_id).to eq("abcd")
        end
      end
    end

    context "when user is not syncable" do
      let(:syncable) { false }

      context "with matching email on mailman side" do
        before do
          expect(api).to receive(:find_user_id).with(email: user.email).and_return("abcd")
        end

        it "deletes remote user" do
          expect(api).to receive(:delete_user).with(id: "abcd")
          expect { perform_job(user) }.not_to have_enqueued_job
        end
      end

      context "with no matching email on mailman side" do
        before do
          expect(api).to receive(:find_user_id).with(email: user.email).and_return(nil)
        end

        it "does nothing" do
          expect(api).not_to receive(:delete_user)
          expect { perform_job(user) }.not_to have_enqueued_job
        end
      end
    end
  end
end
