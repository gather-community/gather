# frozen_string_literal: true

# == Schema Information
#
# Table name: group_mailman_lists
#
#  id                        :bigint           not null, primary key
#  additional_members        :jsonb
#  additional_senders        :jsonb
#  all_cmty_members_can_send :boolean          default(TRUE), not null
#  cluster_id                :bigint           not null
#  created_at                :datetime         not null
#  domain_id                 :bigint           not null
#  group_id                  :bigint           not null
#  last_synced_at            :datetime
#  managers_can_administer   :boolean          default(FALSE), not null
#  managers_can_moderate     :boolean          default(FALSE), not null
#  name                      :string           not null
#  remote_id                 :string
#  updated_at                :datetime         not null
#
require "rails_helper"

describe Groups::Mailman::List do
  describe "factory" do
    it "is valid" do
      create(:group_mailman_list)
    end
  end

  describe "#list_memberships" do
    let!(:mod1) { create(:user, email: "e@e.com", first_name: "Eu", last_name: "Smith") }
    let!(:mod2) { create(:user, email: "f@f.com", first_name: "Fu", last_name: "Smith") }
    let!(:owner1) { create(:user, email: "g@g.com", first_name: "Gu", last_name: "Smith") }
    let!(:owner2) { create(:user, email: "h@h.com", first_name: "Hu", last_name: "Smith") }
    let!(:ownerX) { create(:user, email: "n@n.com", first_name: "Nu", last_name: "Smith") }
    let!(:own_group) { create(:group, joiners: [owner1, owner2], can_administer_email_lists: true) }
    let!(:inactive_own_group) do
      create(:group, :inactive, joiners: [ownerX], can_administer_email_lists: true)
    end
    let!(:own_mod_group) do
      create(:group, joiners: [mod1, mod2], can_administer_email_lists: true, can_moderate_email_lists: true)
    end
    let!(:joiner1) { create(:user, email: "j@j.com", first_name: "Ju", last_name: "Smith") }
    let!(:joiner2) { create(:user, email: "k@k.com", first_name: "Ku", last_name: "Smith") }
    let!(:manager1) { create(:user, email: "l@l.com", first_name: "Lu", last_name: "Smith") }
    let!(:manager2) { create(:user, email: "m@m.com", first_name: "Mu", last_name: "Smith") }
    let!(:mm_user1) { create(:group_mailman_user, user: joiner1, remote_id: "xyz") }
    let!(:non_joiner) { create(:user, email: "i@i.com", first_name: "Iu", last_name: "Smith") }
    let(:managers_can_admin_mod) { false }
    let!(:list) do
      build(:group_mailman_list, group: group,
                                 managers_can_administer: managers_can_admin_mod,
                                 managers_can_moderate: managers_can_admin_mod,
                                 remote_id: "foo.bar.com")
    end

    context "for regular group" do
      let!(:group) { create(:group, availability: "open") }

      before do
        # No opt out memberships since those aren't valid
        group.memberships.create!(group: group, user: joiner1, kind: "joiner")
        group.memberships.create!(group: group, user: joiner2, kind: "joiner")
        group.memberships.create!(group: group, user: manager1, kind: "manager")
        group.memberships.create!(group: group, user: manager2, kind: "manager")
      end

      context "when managers can't administer or moderate" do
        it "returns correct list" do
          expect(list.list_memberships.map(&:list_id).uniq).to eq(["foo.bar.com"])
          expect(summaries(list.list_memberships)).to contain_exactly(
            [false, mod1.id, nil, "e@e.com", "Eu Smith", "owner"],
            [false, mod2.id, nil, "f@f.com", "Fu Smith", "owner"],
            [false, mod1.id, nil, "e@e.com", "Eu Smith", "moderator"],
            [false, mod2.id, nil, "f@f.com", "Fu Smith", "moderator"],
            [false, owner1.id, nil, "g@g.com", "Gu Smith", "owner"],
            [false, owner2.id, nil, "h@h.com", "Hu Smith", "owner"],
            [true, joiner1.id, "xyz", "j@j.com", "Ju Smith", "member"],
            [false, joiner2.id, nil, "k@k.com", "Ku Smith", "member"],
            [false, manager1.id, nil, "l@l.com", "Lu Smith", "member"],
            [false, manager2.id, nil, "m@m.com", "Mu Smith", "member"]
          )
        end

        context "when managers can administer and moderate" do
          let(:managers_can_admin_mod) { true }

          it "returns correct list" do
            expect(list.list_memberships.map(&:list_id).uniq).to eq(["foo.bar.com"])
            expect(summaries(list.list_memberships)).to contain_exactly(
              [false, mod1.id, nil, "e@e.com", "Eu Smith", "owner"],
              [false, mod2.id, nil, "f@f.com", "Fu Smith", "owner"],
              [false, mod1.id, nil, "e@e.com", "Eu Smith", "moderator"],
              [false, mod2.id, nil, "f@f.com", "Fu Smith", "moderator"],
              [false, owner1.id, nil, "g@g.com", "Gu Smith", "owner"],
              [false, owner2.id, nil, "h@h.com", "Hu Smith", "owner"],
              [true, joiner1.id, "xyz", "j@j.com", "Ju Smith", "member"],
              [false, joiner2.id, nil, "k@k.com", "Ku Smith", "member"],
              [false, manager1.id, nil, "l@l.com", "Lu Smith", "member"],
              [false, manager1.id, nil, "l@l.com", "Lu Smith", "moderator"],
              [false, manager1.id, nil, "l@l.com", "Lu Smith", "owner"],
              [false, manager2.id, nil, "m@m.com", "Mu Smith", "member"],
              [false, manager2.id, nil, "m@m.com", "Mu Smith", "moderator"],
              [false, manager2.id, nil, "m@m.com", "Mu Smith", "owner"]
            )
          end
        end
      end
    end

    context "for everybody list" do
      let!(:group) { create(:group, availability: "everybody") }
      let!(:opt_outer) { create(:user, email: "o@o.com", first_name: "Ou", last_name: "Smith") }

      before do
        # No opt out memberships since those aren't valid
        group.memberships.create!(group: group, user: joiner1, kind: "joiner")
        group.memberships.create!(group: group, user: joiner2, kind: "joiner")
        group.memberships.create!(group: group, user: manager1, kind: "manager")
        group.memberships.create!(group: group, user: manager2, kind: "manager")
        group.memberships.create!(group: group, user: opt_outer, kind: "opt_out")
      end

      it "respects opt-outs" do
        expect(list.list_memberships.map(&:list_id).uniq).to eq(["foo.bar.com"])
        expect(summaries(list.list_memberships)).to contain_exactly(
          [false, mod1.id, nil, "e@e.com", "Eu Smith", "owner"],
          [false, mod1.id, nil, "e@e.com", "Eu Smith", "moderator"],
          [false, mod1.id, nil, "e@e.com", "Eu Smith", "member"], # Also a member b/c everybody group
          [false, mod2.id, nil, "f@f.com", "Fu Smith", "owner"],
          [false, mod2.id, nil, "f@f.com", "Fu Smith", "moderator"],
          [false, mod2.id, nil, "f@f.com", "Fu Smith", "member"], # Also a member b/c everybody group
          [false, owner1.id, nil, "g@g.com", "Gu Smith", "owner"],
          [false, owner1.id, nil, "g@g.com", "Gu Smith", "member"], # Also a member b/c everybody group
          [false, owner2.id, nil, "h@h.com", "Hu Smith", "owner"],
          [false, owner2.id, nil, "h@h.com", "Hu Smith", "member"], # Also a member b/c everybody group
          [true, joiner1.id, "xyz", "j@j.com", "Ju Smith", "member"],
          [false, joiner2.id, nil, "k@k.com", "Ku Smith", "member"],
          [false, manager1.id, nil, "l@l.com", "Lu Smith", "member"],
          [false, manager2.id, nil, "m@m.com", "Mu Smith", "member"],
          [false, ownerX.id, nil, "n@n.com", "Nu Smith", "member"],
          [false, non_joiner.id, nil, "i@i.com", "Iu Smith", "member"]
        )
      end
    end

    def summaries(memberships)
      memberships.map do |mship|
        mm_user = mship.mailman_user
        [mm_user.persisted?, mm_user.user_id, mm_user.remote_id,
         mm_user.email, mm_user.display_name, mship.role]
      end
    end
  end
end
