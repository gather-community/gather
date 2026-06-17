# frozen_string_literal: true

require "rails_helper"

describe "search" do
  let(:actor) { create(:user) }
  let(:community) { Defaults.community }

  before do
    use_user_subdomain(actor)
    sign_in(actor)
  end

  describe "GET /search (HTML)" do
    context "without a query" do
      it "renders successfully" do
        get(search_path)
        expect(response).to have_http_status(:ok)
      end
    end

    context "with a query" do
      it "renders successfully" do
        get(search_path, params: {search: "solar"})
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "GET /search (JSON, gather source)", search: Wiki::Page do
    let!(:wiki_page) { create(:wiki_page, community: community, title: "Solar Panels") }

    before { Wiki::Page.__elasticsearch__.refresh_index! }

    it "returns an HTML fragment with a link to the matching wiki page" do
      get(search_path, params: {search: "solar", source: "gather"},
        headers: {"Accept" => "application/json"})
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["html"]).to include(wiki_page_path(slug: wiki_page.slug))
      expect(json["count"]).to be >= 1
      expect(json["next_page_token"]).to be_nil
    end

    context "with no matching results" do
      it "returns a no-results message" do
        get(search_path, params: {search: "xyznonexistent", source: "gather"},
          headers: {"Accept" => "application/json"})
        json = response.parsed_body
        expect(json["html"]).to include("No results found")
        expect(json["count"]).to eq(0)
      end
    end

    context "with drive-only types filter" do
      it "returns no gather results" do
        get(search_path, params: {search: "solar", source: "gather", types: "drive"},
          headers: {"Accept" => "application/json"})
        json = response.parsed_body
        expect(json["html"]).to include("No results found")
        expect(json["count"]).to eq(0)
      end
    end
  end

  describe "GET /search (JSON, drive source)" do
    context "without gdrive config" do
      it "returns no drive results" do
        get(search_path, params: {search: "solar", source: "drive"},
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
        get(search_path, params: {search: "report", source: "drive"},
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
              icon_link: "https://icons.example.com/doc")],
            next_page_token: nil)
        )
      end

      it "passes the user's google_email and mapped drive IDs in the Drive query" do
        expect_any_instance_of(GDrive::Wrapper).to receive(:list_files).with(
          hash_including(q: a_string_including("'jane@example.com' in readers")
                              .and(include("'drive_abc' in parents")))
        )
        get(search_path, params: {search: "budget", source: "drive"},
          headers: {"Accept" => "application/json"})
      end

      it "returns the files the Drive API returns" do
        get(search_path, params: {search: "budget", source: "drive"},
          headers: {"Accept" => "application/json"})
        json = response.parsed_body
        expect(json["html"]).to include("Budget Doc")
      end

      context "when drive is excluded from types filter" do
        it "is handled by the drive column not being requested" do
          # With types=wiki_page (no drive), the drive column simply won't be shown.
          # The search endpoint still responds to ?source=drive but the JS won't call it.
          # This just tests the HTML page renders correctly with drive excluded.
          get(search_path, params: {search: "budget", types: "wiki_page"})
          expect(response).to have_http_status(:ok)
          expect(response.body).not_to include("id=\"drive-pane\"")
        end
      end
    end

    context "when Drive auth fails" do
      let(:actor) { create(:user, google_email: "jane@example.com") }
      let!(:config) { create(:gdrive_config, community: community) }
      let!(:drive_item) { create(:gdrive_item, gdrive_config: config, external_id: "drive_abc") }

      before do
        allow_any_instance_of(GDrive::Wrapper).to receive(:has_credentials?).and_return(true)
        allow_any_instance_of(GDrive::Wrapper).to receive(:list_files)
          .and_raise(Google::Apis::AuthorizationError.new("unauthorized"))
      end

      it "returns an auth error message" do
        get(search_path, params: {search: "budget", source: "drive"},
          headers: {"Accept" => "application/json"})
        json = response.parsed_body
        expect(json["html"]).to include("reconnected to Google Drive")
        expect(json["count"]).to eq(0)
      end
    end
  end

  describe "authorization" do
    context "when not signed in" do
      before { sign_out(actor) }

      it "redirects to sign in" do
        get(search_path)
        expect(response).to redirect_to(/sign-in/)
      end
    end
  end
end
