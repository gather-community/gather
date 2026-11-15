# frozen_string_literal: true

require "rails_helper"

describe GDrive::PermissionAudit do
  let(:config) { create(:gdrive_config) }
  let(:item) { create(:gdrive_item, gdrive_config: config, external_id: "0AGH_tsBj1z-0Uk9PVA") }
  let(:wrapper) { double("wrapper") }
  let(:users) { (1..8).index_with { |n| create(:user, google_email: "u#{n}@example.com") } }
  let!(:group) { create(:group, joiners: [users[1], users[2], users[3]]) }
  let!(:inactive_group) { create(:group, :inactive, joiners: [users[5]]) }

  subject(:discrepancies) do
    described_class.new(wrapper: wrapper, item: item).discrepancies.map(&:to_h)
  end

  before do
    create(:gdrive_item_group, item: item, group: group, access_level: "writer")
    create(:gdrive_item_group, item: item, group: inactive_group, access_level: "writer")

    # Two pages, to check that every page is read.
    page1 = Google::Apis::DriveV3::PermissionList.new(next_page_token: "page2", permissions: [
      perm("u1@example.com", "writer"), # In the group with the right level.
      perm("u3@example.com", "reader"), # In the group but too low. u2 is in the group but has nothing.
      perm("u4@example.com", "commenter"), # Not in any group.
      perm("someone.else@example.com", "writer") # Not a Gather user, so not ours to judge.
    ])
    page2 = Google::Apis::DriveV3::PermissionList.new(permissions: [
      perm("u5@example.com", "writer"), # Only in a deactivated group.
      perm("u6@example.com", "organizer"), # A shared drive Manager, which Gather doesn't manage.
      perm("u7@example.com", "reader", inherited: ["reader"], direct: false), # Only inherits access.
      perm("u8@example.com", "writer", inherited: ["writer"]), # Direct, but no more than it inherits.
      Google::Apis::DriveV3::Permission.new(type: "domain", role: "reader", domain: "example.com")
    ])
    allow(wrapper).to receive(:list_permissions) do |_id, page_token:, **|
      page_token ? page2 : page1
    end
  end

  def perm(email, role, inherited: [], direct: true)
    details = inherited.map { |r| Google::Apis::DriveV3::Permission::PermissionDetail.new(role: r, inherited: true) }
    details << Google::Apis::DriveV3::Permission::PermissionDetail.new(role: role, inherited: false) if direct
    details = nil if inherited.empty?
    Google::Apis::DriveV3::Permission.new(id: "id-#{email}", type: "user", email_address: email,
      role: role, permission_details: details)
  end

  it "finds missing and excess access only" do
    expect(discrepancies).to contain_exactly(
      {kind: :missing_access, user_id: users[2].id, expected_level: "writer", actual_level: nil},
      {kind: :missing_access, user_id: users[3].id, expected_level: "writer", actual_level: "reader"},
      {kind: :excess_access, user_id: users[4].id, expected_level: nil, actual_level: "commenter"},
      {kind: :excess_access, user_id: users[5].id, expected_level: nil, actual_level: "writer"}
    )
  end
end
