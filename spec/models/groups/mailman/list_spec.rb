# frozen_string_literal: true

require "rails_helper"

describe Groups::Mailman::List do
  describe "factory" do
    it "is valid" do
      create(:group_mailman_list)
    end
  end

  describe "validation" do
    shared_examples_for "validates addresses" do |attrib|
      context "with valid lines and one blank line" do
        let(:addresses) { "foo@example.com\n   \n  Bar Q. <bar@example.com>\nbaz@example.com" }
        it { is_expected.to be_valid }
      end

      context "with format error" do
        let(:addresses) { "foo@example.com\nBar Q. <bar@example.com" }
        it { is_expected.to have_errors(attrib => /Error on line 2 \(Bar Q. <bar@example.com\)/) }
      end

      context "with invalid address" do
        let(:addresses) { "fooexample.com\nBar Q. <bar@example.com>" }
        it { is_expected.to have_errors(attrib => /Error on line 1 \(fooexample.com\)/) }
      end

      context "with multiple errors" do
        let(:addresses) { "fooexample.com\nbarexample.com" }

        it "just shows the first" do
          is_expected.to have_errors(attrib => /Error on line 1 \(fooexample.com\)/)
        end
      end
    end

    describe "outside_members" do
      subject(:list) { build(:group_mailman_list, outside_members: addresses) }
      it_behaves_like "validates addresses", :outside_members
    end

    describe "outside_senders" do
      subject(:list) { build(:group_mailman_list, outside_senders: addresses) }
      it_behaves_like "validates addresses", :outside_senders
    end
  end

  describe "outside address cleanup" do
    let(:addresses) { " a@b.com  \n\n  Jo Bol <c@d.com>\nPhil Plomp (Junk) <e@f.com>" }

    shared_examples_for "cleans up addresses" do |attrib|
      it do
        expect(list[attrib]).to eq("a@b.com\nJo Bol <c@d.com>\nPhil Plomp <e@f.com> (Junk)")
      end
    end

    describe "outside_members" do
      subject(:list) { create(:group_mailman_list, outside_members: addresses) }
      it_behaves_like "cleans up addresses", :outside_members
    end

    describe "outside_senders" do
      subject(:list) { create(:group_mailman_list, outside_senders: addresses) }
      it_behaves_like "cleans up addresses", :outside_senders
    end
  end

  describe "#list_memberships" do
    let!(:mod1) { create(:user, email: "e@e.com", first_name: "Eu", last_name: "Smith") }
    let!(:mod2) { create(:user, email: "f@f.com", first_name: "Fu", last_name: "Smith") }
    let!(:owner1) { create(:user, email: "g@g.com", first_name: "Gu", last_name: "Smith") }
    let!(:owner2) { create(:user, email: "h@h.com", first_name: "Hu", last_name: "Smith") }
    let!(:ownerX) { create(:user, email: "n@n.com", first_name: "Nu", last_name: "Smith") }
    let!(:owner_group) { create(:group, joiners: [owner1, owner2], can_administer_email_lists: true) }
    let!(:inactive_owner_group) do
      create(:group, :inactive, joiners: [ownerX], can_administer_email_lists: true)
    end
    let!(:moderator_group) { create(:group, joiners: [mod1, mod2], can_moderate_email_lists: true) }
    let!(:joiner1) { create(:user, email: "j@j.com", first_name: "Ju", last_name: "Smith") }
    let!(:joiner2) { create(:user, email: "k@k.com", first_name: "Ku", last_name: "Smith") }
    let!(:manager1) { create(:user, email: "l@l.com", first_name: "Lu", last_name: "Smith") }
    let!(:manager2) { create(:user, email: "m@m.com", first_name: "Mu", last_name: "Smith") }
    let!(:mm_user1) { create(:group_mailman_user, user: joiner1, remote_id: "xyz") }
    let!(:group) { create(:group, availability: "open") }
    let!(:decoy) { create(:user, email: "i@i.com", first_name: "Iu", last_name: "Smith") }
    let!(:list) do
      build(:group_mailman_list, group: group,
                                 remote_id: "foo.bar.com",
                                 outside_senders: "Al Smith <a@a.com>\nb@b.com",
                                 outside_members: "c@c.com\nd@d.com")
    end

    before do
      group.memberships.create!(group: group, user: joiner1, kind: "joiner")
      group.memberships.create!(group: group, user: joiner2, kind: "joiner")
      group.memberships.create!(group: group, user: manager1, kind: "manager")
      group.memberships.create!(group: group, user: manager2, kind: "manager")
    end

    it "returns correct list" do
      expect(list.list_memberships.map(&:list_id).uniq).to eq(["foo.bar.com"])
      actual = list.list_memberships.map do |mship|
        mm_user = mship.mailman_user
        [mm_user.persisted?, mm_user.user, mm_user.remote_id,
         mm_user.email, mm_user.display_name, mship.role]
      end
      expect(actual).to contain_exactly(
        [false, nil, nil, "a@a.com", "Al Smith", "nonmember"],
        [false, nil, nil, "b@b.com", nil, "nonmember"],
        [false, nil, nil, "c@c.com", nil, "member"],
        [false, nil, nil, "d@d.com", nil, "member"],
        [false, mod1, nil, "e@e.com", "Eu Smith", "moderator"],
        [false, mod2, nil, "f@f.com", "Fu Smith", "moderator"],
        [false, owner1, nil, "g@g.com", "Gu Smith", "owner"],
        [false, owner2, nil, "h@h.com", "Hu Smith", "owner"],
        [true, joiner1, "xyz", "j@j.com", "Ju Smith", "member"],
        [false, joiner2, nil, "k@k.com", "Ku Smith", "member"],
        [false, manager1, nil, "l@l.com", "Lu Smith", "member"],
        [false, manager2, nil, "m@m.com", "Mu Smith", "member"]
      )
    end
  end
end
