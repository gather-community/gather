# frozen_string_literal: true

require "rails_helper"

describe "search" do
  let(:actor) { create(:user) }
  let(:community) { Defaults.community }

  before do
    create(:feature_flag, name: "search", status: true)
    use_user_subdomain(actor)
    sign_in(actor)
  end

  def gather_search(query)
    get(search_path, params: {search: query, source: "gather"}, headers: {"Accept" => "application/json"})
    expect(response).to have_http_status(:ok)
    response.parsed_body["html"]
  end

  def refresh_indices
    SearchController::GATHER_MODELS.each { |m| m.__elasticsearch__.refresh_index! }
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

  describe "result visibility", search: SearchController::GATHER_MODELS do
    let(:own_account) { Billing::Account.find_or_create_by!(household: actor.household, community: community) }
    let(:other_account) { create(:account) }
    let!(:own_txn) { create(:transaction, account: own_account, description: "Soup night dinner") }
    let!(:other_txn) { create(:transaction, account: other_account, description: "Soup night lunch") }

    before { refresh_indices }

    it "shows a regular member only their own household's transactions" do
      html = gather_search("soup")
      expect(html).to include("dinner")
      expect(html).not_to include("lunch")
    end

    context "as a biller" do
      let(:actor) { create(:biller) }

      it "shows all transactions in the community" do
        html = gather_search("soup")
        expect(html).to include("dinner")
        expect(html).to include("lunch")
      end
    end

    context "with emergency contacts" do
      let!(:contact) { create(:emergency_contact, household: create(:household), name: "Zebulon Quartz") }

      before { refresh_indices }

      it "shows them to members of the same community" do
        expect(gather_search("Zebulon")).to include("Zebulon")
      end

      context "when a user from another community in the cluster visits this one" do
        let(:actor) { create(:user, community: create(:community)) }

        before { use_subdomain(community.slug) }

        it "hides them" do
          expect(gather_search("Zebulon")).not_to include("Zebulon")
        end
      end
    end

    context "with a group the member can't see" do
      let!(:hidden_group) { create(:group, name: "Secret Squirrels", availability: "hidden") }

      before { refresh_indices }

      it "hides it" do
        expect(gather_search("squirrels")).not_to include("Secret")
      end
    end
  end

  describe "result display", search: SearchController::GATHER_MODELS do
    it "shows a person found by name only" do
      create(:user, first_name: "Frankie", last_name: "Mertz")
      refresh_indices
      expect(gather_search("Frankie")).to include("Frankie Mertz")
    end

    it "titles transactions with their description" do
      account = Billing::Account.find_or_create_by!(household: actor.household, community: community)
      create(:transaction, account: account, description: "Pencil fee")
      refresh_indices
      html = gather_search("pencil")
      expect(html).to include("<mark>Pencil</mark> fee")
      expect(html).not_to include("untitled")
    end

    it "leaves out a meal's calendar events, since the meal has its own result" do
      meal = create(:meal, :with_menu, title: "Gazpacho Party").tap do |m|
        m.build_events
        m.save!
      end
      create(:event, name: "Gazpacho tasting")
      expect(meal.events.map(&:name)).to contain_exactly(include("Gazpacho"))
      refresh_indices
      html = gather_search("gazpacho")
      expect(html).to include("<mark>Gazpacho</mark> tasting")
      expect(html).to include(meal_path(meal))
      expect(html.scan("<li>").size).to eq(2)
    end

    it "escapes HTML in titles and highlighted snippets" do
      create(:wiki_page, title: "<script>alert(1)</script> Tips",
        content: "Ideas <img src=x onerror=alert(2)>")
      refresh_indices
      html = gather_search("tips ideas")
      expect(html).not_to include("<script>")
      expect(html).not_to include("<img")
      expect(html).to include("&lt;script&gt;")
    end
  end

  describe "authorization" do
    context "when the search feature flag is off" do
      before { FeatureFlag.find_by(name: "search").update!(status: false) }

      it "refuses the page" do
        expect { get(search_path) }.to raise_error(Pundit::NotAuthorizedError)
      end
    end

    context "when not signed in" do
      before { sign_out(actor) }

      it "redirects to sign in" do
        get(search_path)
        expect(response).to redirect_to(/sign-in/)
      end
    end
  end
end
