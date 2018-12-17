# frozen_string_literal: true

require "rails_helper"

describe User do
  describe "validation" do
    describe "phone" do
      let(:user) { build(:user, mobile_phone: phone) }

      context "should allow good phone number" do
        let(:phone) { "7343151234" }
        it { expect(user).to be_valid }
      end

      context "should allow good formatted phone number" do
        let(:phone) { "(734) 315-1234" }
        it { expect(user).to be_valid }
      end

      context "should disallow too-long number" do
        let(:phone) { "73431509811" }
        it do
          expect(user).not_to be_valid
          expect(user.errors[:mobile_phone].join).to eq("is an invalid number")
        end
      end

      context "should disallow formatted too-long number" do
        let(:phone) { "(734) 315-09811" }
        it do
          expect(user).not_to be_valid
          expect(user.errors[:mobile_phone].join).to eq("is an invalid number")
        end
      end
    end

    describe "password strength" do
      let(:user) do
        build(:user, password: password, password_confirmation: password, changing_password: true)
      end

      shared_examples_for "too weak" do
        it do
          expect(user).not_to be_valid
          expect(user.errors[:password].join).to eq("Your password was too weak. "\
            "Try making it longer or adding special characters.")
        end
      end

      context "with new record" do
        context "with weak password" do
          let(:password) { "passw0rd" }
          it_behaves_like "too weak"
        end

        context "with dictionary password" do
          let(:password) { "contortionist" }
          it_behaves_like "too weak"
        end

        context "with strong password" do
          let(:password) { "2a89fhq;*42ata2;84ty8;Q:4t8qa" }
          it { expect(user).to be_valid }
        end

        context "with nil password" do
          let(:password) { nil }
          it do
            expect(user).not_to be_valid
            expect(user.errors[:password].join).to eq("can't be blank")
          end
        end
      end

      context "with persisted record" do
        let(:password) { "2a89fhq;*42ata2;84ty8;Q:4t8qa" }
        let(:saved) do
          create(:user, password: password, password_confirmation: password, changing_password: true)
        end
        let(:user) { User.find(saved.id) } # Reload so password is definitely wiped.

        it "updates cleanly when password not set" do
          user.first_name = "Fish"
          expect(user).to be_valid
        end

        it "updates cleanly when password empty string" do
          user.update(first_name: "Fish", password: "")
          expect(user).to be_valid
        end

        it "errors when password changed and invalid" do
          user.update(first_name: "Fish", password: "foo", password_confirmation: "foo")
          expect(user.errors[:password].join).to match(/was too weak/)
        end
      end
    end

    describe "password confirmation" do
      let(:password) { "2a89fhq;*42ata2;84ty8;Q:4t8qa" }
      let(:user) { build(:user, password: password, password_confirmation: confirmation) }

      context "with matching confirmaiton" do
        let(:confirmation) { password }
        it { expect(user).to be_valid }
      end

      context "without matching confirmation" do
        let(:confirmation) { "x" }
        it do
          expect(user).not_to be_valid
          expect(user.errors[:password_confirmation].join).to eq("Didn't match password")
        end
      end
    end

    describe "email" do
      describe "uniqueness" do
        let(:user) { build(:user, email: email).tap(&:validate) }

        context "with unused email" do
          let(:email) { "a@b.com" }
          it { expect(user).to be_valid }
        end

        context "with taken email" do
          let!(:other_user) { create(:user, email: "a@b.com") }
          let(:email) { "a@b.com" }
          it { expect(user.errors[:email]).to eq(["has already been taken"]) }
        end

        context "with email taken in other cluster" do
          let(:other_cmty) { with_tenant(create(:cluster)) { create(:community) } }
          let!(:other_user) { create(:user, community: other_cmty, email: "a@b.com") }
          let(:email) { "a@b.com" }

          it do
            with_tenant(create(:cluster)) do
              pp user.cluster_id
              expect(user.cluster_id).not_to eq(other_user.cluster_id)
              expect(user.errors[:email]).to eq(["has already been taken"])
            end
          end
        end
      end
    end
  end

  describe "roles" do
    let(:user) { create(:user) }

    describe "getter/setters" do
      it "should read and write properly" do
        user.role_biller = true
        expect(user.role_biller).to be(true)
        expect(user.has_role?(:biller)).to be(true)
      end

      it "should work via mass assignment" do
        user.update!(role_admin: true)
        expect(user.reload.has_role?(:admin)).to be(true)
        user.update!(role_admin: false)
        expect(user.reload.has_role?(:admin)).to be(false)
      end
    end

    describe "#global_role?" do
      let(:meal) { create(:meal) }

      it "gets global role" do
        user.add_role(:foo)
        expect(user.global_role?(:foo)).to be(true)
      end

      it "doesn't get scoped role" do
        user.add_role(:foo, meal)
        expect(user.global_role?(:foo)).to be(false)
      end

      it "doesn't get global role set after first call" do
        user.global_role?(:foo)
        user.add_role(:foo)
        expect(user.global_role?(:foo)).to be(false)
      end
    end
  end

  describe "active_for_authentication?" do
    shared_examples_for "active_for_auth" do |bool|
      it "should be true/false" do
        expect(user.active_for_authentication?).to be(bool)
      end
    end

    context "regular user" do
      let(:user) { build(:user) }
      it_behaves_like "active_for_auth", true
    end

    context "inactive user" do
      let(:user) { build(:user, :inactive) }
      it_behaves_like "active_for_auth", true
    end

    context "active child" do
      let(:user) { build(:user, :child) }
      it_behaves_like "active_for_auth", false
    end

    context "inactive child" do
      let(:user) { build(:user, :inactive, :child) }
      it_behaves_like "active_for_auth", false
    end
  end

  describe "photo" do
    it "should be created by factory when requested" do
      expect(create(:user, :with_photo).photo.size).to be > 0
    end

    it "should return missing image when no photo" do
      expect(create(:user).photo(:medium)).to eq("missing/users/medium.png")
    end
  end

  describe "#any_assignments?" do
    let(:user) { create(:user) }
    subject { user.any_assignments? }

    context "with nothing" do
      it { is_expected.to be(false) }
    end

    context "with meal assignment" do
      before { user.meal_assignments.create!(role: "cleaner", meal: create(:meal)) }
      it { is_expected.to be(true) }
    end

    context "with work assignment" do
      before { user.work_assignments.create!(shift: create(:work_shift)) }
      it { is_expected.to be(true) }
    end
  end

  # Our approach to destruction is to:
  # - Set the policy to only allow deletions that won't trigger foreign key constraints.
  # - Set the `dependent` option to nullify or destroy as appropriate for legal deletions.
  # - Not to set the `dependent` option for illegal destroys and let the DB raise an error if one
  #   is somehow attempted.
  # - In the model spec, test for the appropriate behavior (dependent destruction, nullification, or error)
  #   for each foreign key.
  # - In the policy spec, test for the appropriate restrictions on destroy.
  # - In the feature spec, test the destruction/deactivation/activation happy paths.
  describe "destruction" do
    shared_examples_for "raises foreign key error" do
      it "raises error" do
        expect { user.destroy }.to raise_error(ActiveRecord::InvalidForeignKey)
      end
    end

    context "adult with role" do
      let!(:user) { create(:user) }

      context "with meal assignment" do
        let!(:meal) { create(:meal, head_cook: user) }

        it "destroys cleanly" do
          user.destroy
          expect(meal.reload.head_cook).to be_nil
        end
      end

      context "with job assignment and share" do
        let!(:period) { create(:work_period) }
        let!(:share) { create(:work_share, user: user, period: period) }
        let!(:job) { create(:work_job, period: period) }
        let!(:assignment) { create(:work_assignment, user: user, shift: job.shifts[0]) }

        it "destroys cleanly" do
          user.destroy
          expect { job.reload }.not_to raise_error
          expect { share.reload }.to raise_error(ActiveRecord::RecordNotFound)
          expect { assignment.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end

      context "with parent" do
        let!(:child) { create(:user, :child, guardians: [user]) }

        it "destroys cleanly without destroying parent" do
          expect(user.reload.down_guardianships).not_to be_empty
          child.destroy
          expect(user.reload.up_guardianships).to be_empty
        end
      end

      context "with child" do
        let!(:child) { create(:user, :child, guardians: [user]) }

        it "destroys cleanly without destroying child" do
          expect(child.reload.up_guardianships).not_to be_empty
          user.destroy
          expect(child.reload.up_guardianships).to be_empty
        end
      end

      context "with job choosing proxy" do
        let!(:proxy) { create(:user, job_choosing_proxy: user) }

        it "destroys cleanly" do
          user.destroy
          expect(proxy.reload.job_choosing_proxy).to be_nil
        end
      end

      context "with meal creation record" do
        let!(:meal) { create(:meal, creator: user) }
        it_behaves_like "raises foreign key error"
      end

      context "with reservation reserver record" do
        let!(:reservation) { create(:reservation, reserver: user) }
        it_behaves_like "raises foreign key error"
      end

      context "with reservation sponsor record" do
        let!(:reservation) { create(:reservation, sponsor: user) }
        it_behaves_like "raises foreign key error"
      end

      context "with wiki page creator record" do
        let!(:wiki_page) { create(:wiki_page, creator: user) }
        it_behaves_like "raises foreign key error"
      end

      context "with wiki page updator record" do
        let!(:wiki_page) { create(:wiki_page, updator: user) }
        it_behaves_like "raises foreign key error"
      end
    end
  end
end
