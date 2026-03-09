# frozen_string_literal: true

require "rails_helper"

describe "wiki search" do
  let(:actor) { create(:user) }
  let(:community) { Defaults.community }

  before do
    use_user_subdomain(actor)
    sign_in(actor)
  end

  describe "GET /wiki/search" do
    context "without a query" do
      it "renders successfully" do
        get(wiki_search_path)
        expect(response).to have_http_status(:ok)
      end
    end

    context "with a query" do
      it "renders successfully" do
        get(wiki_search_path, params: {search: "solar"})
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "GET /wiki/search (JSON, wiki source)", search: Wiki::Page do
    let!(:wiki_page) { create(:wiki_page, community: community, title: "Solar Panels") }

    before { Wiki::Page.__elasticsearch__.refresh_index! }

    it "returns an HTML fragment with a link to the matching page" do
      get(wiki_search_path, params: {search: "solar", source: "wiki"},
                            headers: {"Accept" => "application/json"})
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["html"]).to include(wiki_page_path(slug: wiki_page.slug))
      expect(json["next_page_token"]).to be_nil
    end
  end

  describe "GET /wiki/search (JSON, drive source)" do
    context "without gdrive config" do
      it "returns no drive results" do
        get(wiki_search_path, params: {search: "solar", source: "drive"},
                              headers: {"Accept" => "application/json"})
        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["html"]).to include("No Drive files found")
        expect(json["next_page_token"]).to be_nil
      end
    end

    context "when actor has no google_email" do
      let(:actor) { create(:user, google_email: nil) }

      it "returns no drive results without calling the Drive API" do
        expect_any_instance_of(GDrive::Wrapper).not_to receive(:list_files)
        get(wiki_search_path, params: {search: "report", source: "drive"},
                              headers: {"Accept" => "application/json"})
        json = response.parsed_body
        expect(json["html"]).to include("No Drive files found")
      end
    end

    context "with config, credentials, a google_email, and a mapped drive" do
      let(:actor) { create(:user, google_email: "jane@example.com") }
      let!(:config) { create(:gdrive_config, community: community) }
      let!(:drive_item) { create(:gdrive_item, gdrive_config: config, external_id: "drive_abc") }

      before do
        allow_any_instance_of(GDrive::Wrapper).to receive(:has_credentials?).and_return(true)
        allow_any_instance_of(GDrive::Wrapper).to receive(:list_files).and_return(
          instance_double(Google::Apis::DriveV3::FileList,
                          files: [instance_double(Google::Apis::DriveV3::File,
                                                  name: "Budget Doc",
                                                  web_view_link: "https://drive.google.com/f1",
                                                  icon_link: "https://drive-thirdparty.googleusercontent.com/16/type/doc")],
                          next_page_token: nil)
        )
      end

      it "passes the user's google_email and mapped drive IDs in the Drive query" do
        expect_any_instance_of(GDrive::Wrapper).to receive(:list_files).with(
          hash_including(q: a_string_including("'jane@example.com' in readers")
                              .and(include("'drive_abc' in parents")))
        )
        get(wiki_search_path, params: {search: "budget", source: "drive"},
                              headers: {"Accept" => "application/json"})
      end

      it "returns all files the Drive API returns" do
        get(wiki_search_path, params: {search: "budget", source: "drive"},
                              headers: {"Accept" => "application/json"})
        json = response.parsed_body
        expect(json["html"]).to include("Budget Doc")
      end
    end
  end

  describe "authorization" do
    context "when not signed in" do
      before { sign_out(actor) }

      it "redirects to sign in" do
        get(wiki_search_path)
        expect(response).to redirect_to(/sign-in/)
      end
    end
  end
end
