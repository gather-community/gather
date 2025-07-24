# frozen_string_literal: true

require "rails_helper"

describe User do
  describe ".in_household" do
    let!(:household) { create(:household, member_count: 0) }
    let!(:parent) { create(:user, household: household) }
    let!(:child1) { create(:user, :child, household: household) }
    let!(:child2) { create(:user, :child, guardians: [parent]) }
    let!(:decoy1) { create(:user) }
    let!(:decoy2) { create(:user, :child) }

    it "matches direct members and members by parentage" do
      expect(User.in_household(household)).to contain_exactly(parent, child1, child2)
    end
  end

  describe "search" do
    let!(:users) do
      [
        create(:user, first_name: "Gordon", last_name: "Druck",
          household: create(:household, member_count: 0, unit_num_and_suffix: "99B")),
        create(:user, first_name: "Soox", last_name: "Druck",
          household: create(:household, member_count: 0, unit_num_and_suffix: "99")),
        create(:user, first_name: "Ralla", last_name: "Bington",
          household: create(:household, member_count: 0, unit_num_and_suffix: "99X")),
        create(:user, first_name: "Pooda", last_name: "Bington",
          household: create(:household, member_count: 0, unit_num_and_suffix: "99X")),
        create(:user, first_name: "Lordum", last_name: "Zobstra",
          household: create(:household, member_count: 0, unit_num_and_suffix: "")),
        create(:user, first_name: "Nuru", last_name: "Rog",
          household: create(:household, member_count: 0, unit_num_and_suffix: "X"))
      ]
    end

    it "matches partial first_name" do
      expect(User.matching("don")).to contain_exactly(users[0])
    end

    it "matches full first_name" do
      expect(User.matching("gordon")).to contain_exactly(users[0])
    end

    it "matches partial last_name" do
      expect(User.matching("Dru")).to contain_exactly(users[0], users[1])
    end

    it "matches full last_name" do
      expect(User.matching("Druck")).to contain_exactly(users[0], users[1])
    end

    it "matches full name" do
      expect(User.matching("Gordon Druck")).to contain_exactly(users[0])
    end

    it "matches exact unit number with suffix with or without -, or exact unit number" do
      expect(User.matching("10")).to be_empty
      expect(User.matching("99B")).to contain_exactly(users[0])
      expect(User.matching("99-B")).to contain_exactly(users[0])
      expect(User.matching("99")).to contain_exactly(users[0], users[1], users[2], users[3])
      expect(User.matching("99X")).to contain_exactly(users[2], users[3])
      expect(User.matching("99-X")).to contain_exactly(users[2], users[3])
      expect(User.matching("x")).to contain_exactly(users[1], users[5])
    end
  end

  describe "normalization" do
    let(:user) { build(:user, submitted) }
    let(:user2) { create(:user) }

    # Get the normalized values for the submitted keys.
    subject { submitted.keys.map { |k| [k, user.send(k)] }.to_h }

    before do
      user.validate
    end

    describe "full_access, child" do
      context "with child true" do
        let(:submitted) { {child: true, full_access: false} }
        it { is_expected.to eq(child: true, full_access: false) }
      end

      context "with child false" do
        let(:submitted) { {child: false, full_access: false} }
        it { is_expected.to eq(child: false, full_access: true) }
      end
    end

    describe "google_email, job_choosing_proxy, reset_password_token, confirmed_at, roles" do
      let(:now) { Time.current }

      context "with full_access true" do
        let(:submitted) do
          {google_email: "a@b.com", job_choosing_proxy_id: user2.id, reset_password_token: "xyz",
           child: true, full_access: true, role_admin: true, role_biller: true,
           confirmed_at: now}
        end

        it do
          is_expected.to eq(google_email: "a@b.com", job_choosing_proxy_id: user2.id,
            child: true, reset_password_token: "xyz", full_access: true,
            role_admin: true, role_biller: true, confirmed_at: now)
        end
      end

      context "with full_access false" do
        let(:submitted) do
          {google_email: "a@b.com", job_choosing_proxy_id: user2.id, child: true, reset_password_token: "xyz",
           full_access: false, role_admin: true, role_biller: true, confirmed_at: now}
        end

        it do
          is_expected.to eq(google_email: nil, job_choosing_proxy_id: nil, child: true,
            reset_password_token: nil, full_access: false,
            role_admin: false, role_biller: false, confirmed_at: nil)
        end
      end
    end

    describe "guardians" do
      context "with regular child" do
        let(:user) { build(:user, :child) }

        it "doesn't remove guardians" do
          expect(user.up_guardianships).not_to be_empty
        end
      end

      context "with full_access child" do
        let(:user) { build(:user, :full_access_child) }

        it "doesn't remove guardians" do
          expect(user.up_guardianships).not_to be_empty
        end
      end

      context "with adult" do
        context "with preexisting guardians" do
          let(:user) { create(:user, :full_access_child).tap { |u| u.child = false } }

          it "removes guardians" do
            expect(user.up_guardianships).to be_empty
          end
        end

        context "with non-preexisting guardians" do
          let(:user) do
            build(:user, up_guardianships_attributes: {"0" => {guardian_id: create(:user).id.to_s}})
          end

          it "removes guardians" do
            expect(user.up_guardianships).to be_empty
          end
        end
      end
    end
  end

  describe "validation" do
    context "with no data" do
      it "should not error" do
        expect(User.new).to be_invalid
      end
    end

    describe "age certification" do
      context "with full access child" do
        context "with new record" do
          context "with age certification '0'" do
            subject(:user) { build(:user, :full_access_child, certify_13_or_older: "0") }

            it do
              expect(user).not_to be_valid
              expect(user.errors[:certify_13_or_older].join)
                .to eq("Age certification is required for children with full access")
            end
          end

          context "with age certification" do
            context "with no birthday" do
              subject(:user) { build(:user, :full_access_child, certify_13_or_older: "1", birthdate: nil) }
              it { is_expected.to be_valid }
            end

            context "with non-year birthday" do
              subject(:user) do
                build(:user, :full_access_child, certify_13_or_older: "1", birthdate: "0004-01-01")
              end
              it { is_expected.to be_valid }
            end

            context "with birthday" do
              subject(:user) do
                build(:user, :full_access_child, certify_13_or_older: true, birthday_str: birthdate)
              end

              context "with valid birthday" do
                let(:birthdate) { (Time.current - 14.years).to_fs(:no_time) }
                it { is_expected.to be_valid }
              end

              context "with invalid birthday" do
                let(:birthdate) { (Time.current - 12.years).to_fs(:no_time) }

                it do
                  expect(user).not_to be_valid
                  expect(user.errors[:birthday_str].join)
                    .to eq("Children must be 13 years of age or older to have full access")
                end
              end
            end
          end
        end

        # Once a user has full access, we shouldn't need them to check the box on every edit.
        context "with reloaded persisted record" do
          let(:user) { create(:user, :full_access_child) }

          context "with unrelated change" do
            subject(:reloaded_user) { User.find(user.id).tap { |u| u.last_name = "Fizz" } }

            it { is_expected.to be_valid }
          end
        end
      end

      context "with regular child" do
        subject(:user) { build(:user, :child) }
        it { is_expected.to be_valid }
      end

      context "with adult" do
        context "with newly created adult" do
          subject(:user) { build(:user) }
          it { is_expected.to be_valid }
        end

        context "with adult who was previously child" do
          subject(:user) { create(:user, :child).tap { |u| u.child = false } }

          it do
            expect(user).not_to be_valid
            expect(user.errors[:certify_13_or_older].join)
              .to eq("Age certification is required for changing child to adult")
          end
        end
      end
    end

    # See phoneable_spec.rb for more phone normalization and validation specs.
    describe "phone" do
      let(:user) { build(:user, mobile_phone: phone) }

      context "should allow good phone number" do
        let(:phone) { "7343151234" }
        it { expect(user).to be_valid }
      end
    end

    describe "password strength" do
      let(:user) do
        build(:user, password: password, password_confirmation: password, changing_password: true)
      end

      shared_examples_for "too weak" do
        it do
          expect(user).not_to be_valid
          expect(user.errors[:password].join).to eq("Your password was too weak. " \
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
      describe "presence" do
        context "adult" do
          subject(:user) { build(:user, email: nil) }
          it { is_expected.to have_errors(email: "can't be blank") }
        end

        context "full_access_child" do
          subject(:user) { build(:user, :full_access_child, email: nil) }
          it { is_expected.to have_errors(email: "can't be blank") }
        end

        context "child" do
          subject(:user) { build(:user, :child, email: nil) }
          it { is_expected.to be_valid }
        end

        context "inactive adult" do
          subject(:user) { build(:user, :inactive, email: nil) }
          it { is_expected.to be_valid }
        end
      end

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

    context "full_access_child" do
      let(:user) { build(:user, :full_access_child) }
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
      expect(create(:user, :with_photo).photo).to be_attached
    end
  end

  # This is important because we use reset_password_token for sign in invitations and thus email
  # confirmations. If the user's email changes we can't accept the old invite.
  describe "changing email deletes reset_password_token" do
    let(:user) { create(:user) }
    subject { user.reset_password_token }

    before { user.reset_reset_password_token! }

    context "with email change" do
      before do
        user.reload
        user.update!(email: "new@foo.com")
      end

      it { is_expected.to be_nil }
    end

    context "with email change but no reconfirm" do
      before do
        user.reload
        user.skip_reconfirmation!
        user.update!(email: "new@foo.com")
      end

      it { is_expected.to be_nil }
    end

    context "without email change" do
      before do
        user.reload
        user.update!(first_name: "Ruddiger")
      end

      it { is_expected.not_to be_nil }
    end
  end

  describe "confirmation" do
    # For coverage of most of confirmation behavior, we rely on Devise's tests.
    # Here we only test things that are non-standard.
    # A lot of confirmation-related stuff is handled at the controller level and covered in feature specs.
    describe "unsetting email on confirmed user" do
      # Only way to unset email on confirmed user is if they're inactive.
      let(:user) { create(:user, :inactive) }

      it "unsets confirmed flag" do
        user.update!(email: nil)
        expect(user.reload).not_to be_confirmed
      end
    end
  end

  # Our approach to destruction is to:
  # - Set the policy to only disallow deletions based on what users of various roles should be able
  #   to destroy given various combinations of existing associations.
  # - Set association `dependent` options to avoid DB constraint errors UNLESS the destroy is never allowed.
  # - In the model spec, assume destroy has been called and test for the appropriate behavior
  #   (dependent destruction, nullification, or error) for each foreign key.
  # - In the policy spec, test for the appropriate restrictions on destroy.
  # - In the feature spec, test the destruction/deactivation/activation happy paths.
  # - For fake users and households, destruction may happen when associations are present that would
  #   normally forbid it, but the deletion script can be ordered in such a way as to avoid problems by
  #   deleting dependent objects first, and then users and households.
  describe "destruction" do
    let!(:user) { create(:user) }

    context "with meal assignment" do
      let!(:meal) { create(:meal, head_cook: user) }

      it "destroys user and assignment cleanly but not meal" do
        user.destroy
        expect(Meals::Assignment.count).to be_zero
        expect(meal.reload.head_cook).to be_nil
      end
    end

    context "with job assignment and share" do
      let!(:period) { create(:work_period) }
      let!(:share) { create(:work_share, user: user, period: period) }
      let!(:job) { create(:work_job, period: period) }
      let!(:assignment) { create(:work_assignment, user: user, shift: job.shifts[0]) }

      it "destroys cleanly and cascades" do
        user.destroy
        expect { job.reload }.not_to raise_error
        expect { share.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect { assignment.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "with group membership" do
      let!(:membership) { create(:group_membership, user: user) }

      it "destroys cleanly and cascades" do
        user.destroy
        expect { membership.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "with group mailman user" do
      let!(:mailman_user) { create(:group_mailman_user, user: user) }

      it "destroys cleanly and cascades" do
        user.destroy
        expect { mailman_user.reload }.to raise_error(ActiveRecord::RecordNotFound)
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

      it "destroys cleanly and nullifies" do
        user.destroy
        expect(proxy.reload.job_choosing_proxy).to be_nil
      end
    end

    context "with meal creation record" do
      let!(:meal) { create(:meal, creator: user) }
      it { expect { user.destroy }.to raise_error(ActiveRecord::InvalidForeignKey) }
    end

    context "with event creator record" do
      let!(:event) { create(:event, creator: user) }
      it { expect { user.destroy }.to raise_error(ActiveRecord::InvalidForeignKey) }
    end

    context "with event sponsor record" do
      let!(:event) { create(:event, sponsor: user) }
      it { expect { user.destroy }.to raise_error(ActiveRecord::InvalidForeignKey) }
    end

    context "with wiki page creator record" do
      let!(:wiki_page) { create(:wiki_page, creator: user) }
      it { expect { user.destroy }.to raise_error(ActiveRecord::InvalidForeignKey) }
    end

    context "with wiki page updater record" do
      let!(:wiki_page) { create(:wiki_page, updater: user) }
      it { expect { user.destroy }.to raise_error(ActiveRecord::InvalidForeignKey) }
    end

    context "with memorial" do
      let!(:memorial) { create(:memorial, user: user) }
      it "deletes cleanly" do
        user.destroy
        expect { memorial.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "with memorial message" do
      let!(:memorial_message) { create(:memorial_message, author: user) }
      it "deletes cleanly" do
        user.destroy
        expect { memorial_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
