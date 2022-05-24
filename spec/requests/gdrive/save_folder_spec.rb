# frozen_string_literal: true

require "rails_helper"

describe "gdrive auth save_folder" do
  let(:actor) { create(:admin) }

  before do
    sign_in(actor)
    create(:feature_flag, name: "gdrive", status: true)
    use_user_subdomain(actor)
  end

  context "when saved credentials are present" do
    let!(:gdrive_config) { create(:gdrive_config) }

    it "saves folder and redirects to index" do
      put(gdrive_auth_save_folder_path, params: {folder_id: "xyz"})
      expect(response).to redirect_to(gdrive_auth_url(subdomain: nil, community_id: Defaults.community.id))
      ActsAsTenant.with_tenant(Defaults.cluster) do
        expect(GDrive::Config.find_by!(community_id: Defaults.community.id).folder_id).to eq('xyz')
      end
    end
  end
end
