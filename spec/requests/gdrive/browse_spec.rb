# frozen_string_literal: true

require "rails_helper"

describe "gdrive browse" do
  let(:community) { Defaults.community }
  let(:community2) { create(:community) }
  let(:actor) { create(:user, community: community) }
  let!(:config) { create(:gdrive_config, community: community, org_user_id: "drive.admin@example.com") }
  let!(:token) { create(:gdrive_token, gdrive_config: config, google_user_id: "drive.admin@example.com") }
  let!(:config2) { create(:gdrive_config, community: community2) }

  # The actor can see a drive in their own community's config, so they get past the "no drives" check.
  let(:own_group) { create(:group, communities: [community], joiners: [actor]) }
  let(:own_drive) { create(:gdrive_item, gdrive_config: config, kind: "drive", external_id: "0AownDrive") }

  # A drive in the other community's config. The actor is in a group with access to it, but it isn't
  # part of this community's Drive connection.
  let(:shared_group) { create(:group, communities: [community, community2], joiners: [actor]) }
  let(:other_drive) do
    create(:gdrive_item, gdrive_config: config2, kind: "drive", external_id: "0AotherDrive")
  end

  before do
    create(:gdrive_item_group, item: own_drive, group: own_group)
    create(:gdrive_item_group, item: other_drive, group: shared_group)
    use_user_subdomain(actor)
    sign_in(actor)
  end

  it "won't list another community's drive through this community's connection" do
    expect_any_instance_of(GDrive::Wrapper).not_to receive(:list_files)
    get("/gdrive/item/0AotherDrive", params: {drive: 1})
    expect(response).to have_http_status(:not_found)
  end
end
