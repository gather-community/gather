# frozen_string_literal: true

require "rails_helper"

describe "mailman integration" do
  let!(:community) { Defaults.community }
  let!(:communityB) { create(:community) }
  let!(:domain) { create(:domain, name: "foo.com") }
  let!(:user1) { create(:user, id: 100, first_name: "Alpha", last_name: "Smith", email: "a@x.com") }
  let!(:user2) { create(:user, id: 101, first_name: "Bravo", last_name: "Smith", email: "b@x.com") }
  let!(:user3) { create(:user, id: 102, first_name: "Charlie", last_name: "Smith", email: "c@x.com") }
  let!(:user4) { create(:user, id: 103, first_name: "Hotel", last_name: "Smith", email: "h@x.com") }

  # When developing this spec, to do a fresh run, *delete the cassettes*, and then in the mailman venv:
  #   In the root dir:
  #     mailman stop && rm -rf var/data/* && mailman start
  #   And in the mailman-suite/mailman-suite_project dir
  #     Ctrl-c (stop server)
  #     rm mailmansuite.db && python3 manage.py migrate && python3 manage.py runserver
  # Then run the spec.
  it "makes expected api calls" do
    perform_enqueued_jobs do
      group = nil
      admin_group = nil
      list = nil
      membership = nil
      step("create_regular_group") do
        group = create(:group, availability: "open", joiners: [user1, user2])
      end
      step("create_list") do
        list = create(:group_mailman_list, name: "zulu", group: group, domain: domain,
                                           outside_members: "Delta Smith <d@x.com>\ne@x.com",
                                           outside_senders: "f@x.com")
      end
      step("add_member") do
        membership = group.memberships.create!(user: user3, kind: "manager")
      end
      step("remove_member") do
        membership.destroy
      end
      step("update_user") do
        user1.update!(first_name: "Alphonzo")
      end
      step("destroy_user") do
        user1.destroy
      end
      step("deactivate_member") do
        user2.deactivate
      end
      step("change_outside_senders_and_members") do
        list.outside_members = "e@x.com"
        list.outside_senders = "f@x.com\ng@x.com"
        list.save!
      end
      step("create_admin_group") do
        admin_group = create(:group, joiners: [user3], can_administer_email_lists: true)
      end
      step("add_moderate_permission") do
        admin_group.update!(can_moderate_email_lists: true)
      end
      step("add_admin_group_member") do
        admin_group.memberships.create!(user: user4, kind: "joiner")
      end
      step("destroy_admin_group") do
        admin_group.destroy
      end
      step("destroy_list") do
        list.reload
        list.destroy
      end
      step("change_to_everybody_group") do
        group.reload
        group.update!(availability: "everybody")
      end
      step("create_list_for_everybody_group") do
        list = create(:group_mailman_list, name: "yankee", group: group, domain: domain,
                                           outside_members: nil, outside_senders: nil)
      end
      step("create_user_and_ensure_added") do
        create(:user, id: 104, first_name: "Indigo", last_name: "Smith", email: "i@x.com")
      end
      step("change_member_community_and_ensure_removed_from_everybody_group") do
        user4.household.update!(community: communityB)
      end
      step("deactivate_group") do
        group.deactivate
      end
    end
  end

  def step(name)
    Groups::Mailman::SyncListener.instance.reset_duplicate_tracking!
    [user1, user2, user3, user4].each { |o| o.reload unless o.destroyed? }
    VCR.use_cassette("groups/mailman/integration/#{name}") { yield }
  end
end
