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
      expect(json["next_offset"]).to be_nil
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
        get(search_path, params: {search: "solar", source: "gather", types: "drive_doc"},
          headers: {"Accept" => "application/json"})
        json = response.parsed_body
        expect(json["html"]).to include("No results found")
        expect(json["count"]).to eq(0)
      end
    end
  end

  describe "GET /search (JSON, drive source)" do
    context "without gdrive config" do
      it "is not found, since the community has no Drive search" do
        get(search_path, params: {search: "solar", source: "drive"},
          headers: {"Accept" => "application/json"})
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when actor has no google_email" do
      let(:actor) { create(:user, google_email: nil) }
      let!(:config) { create(:gdrive_config, community: community) }

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
              id: "f1",
              name: "Budget Doc",
              drive_id: "drive_abc",
              mime_type: "application/vnd.google-apps.document",
              modified_time: Time.zone.parse("2026-10-20 10:00"),
              web_view_link: "https://drive.google.com/f1",
              icon_link: "https://icons.example.com/doc")],
            next_page_token: nil)
        )
      end

      it "searches all drives as the user's google_email" do
        expect_any_instance_of(GDrive::Wrapper).to receive(:list_files).with(
          hash_including(corpora: "allDrives", q: a_string_including("'jane@example.com' in readers"))
        )
        get(search_path, params: {search: "budget", source: "drive"},
          headers: {"Accept" => "application/json"})
      end

      it "marks the count as capped only when Drive has more pages" do
        get(search_path, params: {search: "budget", source: "drive"},
          headers: {"Accept" => "application/json"})
        expect(response.parsed_body["capped"]).to be(false)

        allow_any_instance_of(GDrive::Searcher).to receive(:search)
          .and_return({files: [], next_page_token: "token_abc"})
        get(search_path, params: {search: "budget", source: "drive"},
          headers: {"Accept" => "application/json"})
        expect(response.parsed_body["capped"]).to be(true)
      end

      it "shows each file's type and modified date" do
        get(search_path, params: {search: "budget", source: "drive"},
          headers: {"Accept" => "application/json"})
        expect(response.parsed_body["html"]).to include("Google Doc · Modified")
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

    context "with an event on a calendar that other communities are forbidden to see" do
      let(:calendar) { create(:calendar, name: "Private Lounge") }
      let!(:event) { create(:event, name: "Poker night", calendar: calendar) }

      before do
        create(:calendar_protocol, calendars: [calendar], other_communities: "forbidden")
        refresh_indices
      end

      it "shows it to members of this community" do
        expect(gather_search("poker")).to include("Private Lounge")
      end

      context "when a user from another community visits this one" do
        let(:actor) { create(:user, community: create(:community)) }

        before { use_subdomain(community.slug) }

        it "hides it" do
          expect(gather_search("poker")).not_to include("Private Lounge")
        end
      end
    end

    context "with a pet whose household has left the community" do
      let(:household) { create(:household) }
      let!(:pet) { create(:pet, name: "Waffles", household: household) }

      it "hides it even though the index still has the old community" do
        refresh_indices
        household.update_column(:community_id, create(:community).id)
        expect(gather_search("waffles")).not_to include("Waffles")
      end
    end

    it "links a transaction with no statement to its account, which the member can see" do
      expect(gather_search("dinner")).to include(account_path(own_account))
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

  describe "paging", search: SearchController::GATHER_MODELS do
    before do
      12.times { |i| create(:wiki_page, community: community, title: "Compost tip #{i + 1}") }
      refresh_indices
    end

    def gather_page(offset)
      get(search_path, params: {search: "compost", source: "gather", offset: offset},
        headers: {"Accept" => "application/json"})
      response.parsed_body
    end

    it "counts every visible hit but loads records only for the page shown" do
      expect_any_instance_of(Search::Visibility).to receive(:load_hits)
        .with(have_attributes(size: 10)).and_call_original
      json = gather_page(0)
      expect(json["count"]).to eq(12)
      expect(json["html"].scan("<li>").size).to eq(10)
      expect(json["next_offset"]).to eq(10)
    end

    it "serves later pages from the cached results without searching again" do
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
      gather_page(0)
      expect(Elasticsearch::Model).not_to receive(:search)
      json = gather_page(10)
      expect(json["html"].scan("<li>").size).to eq(2)
    end

    it "searches again for a later page when the cached results have expired" do
      cache = ActiveSupport::Cache::MemoryStore.new
      allow(Rails).to receive(:cache).and_return(cache)
      gather_page(0)
      Timecop.travel(SearchController::RESULTS_CACHE_EXPIRY + 1.minute) do
        json = gather_page(10)
        expect(json["html"].scan("<li>").size).to eq(2)
        expect(json["next_offset"]).to be_nil
      end
    end

    # The test cache store keeps nothing, so every later page searches again, as after expiry.
    it "returns an empty page, not an error, if the results shrank after the cache expired" do
      gather_page(0)
      ActsAsTenant.with_tenant(community.cluster) do
        Wiki::Page.where("title LIKE ?", "Compost%").where.not(title: "Compost tip 1").destroy_all
      end
      refresh_indices
      json = gather_page(10)
      expect(response).to have_http_status(:ok)
      expect(json["html"]).not_to include("<li>")
      expect(json).to include("count" => 1, "next_offset" => nil)
    end

    it "returns just the remaining list items for a later page" do
      json = gather_page(10)
      expect(json["html"].scan("<li>").size).to eq(2)
      expect(json["html"]).not_to include("<ul")
      expect(json["next_offset"]).to be_nil
    end
  end

  describe "query matching", search: SearchController::GATHER_MODELS do
    let!(:pizza) { create(:meal, :with_menu, title: "Pizza night") }
    let!(:german) { create(:meal, :with_menu, title: "German feast") }
    let!(:potato_bar) { create(:meal, :with_menu, title: "Baked potato bar") }
    let!(:potato_salad) { create(:meal, :with_menu, title: "Potato salad, baked beans") }

    before { refresh_indices }

    it "requires every word to match" do
      expect(gather_search("pizza german")).to include("No results found")
      html = gather_search("potato baked")
      expect(html).to include(meal_path(potato_bar))
      expect(html).to include(meal_path(potato_salad))
    end

    it "matches a quoted phrase exactly" do
      html = gather_search('"baked potato"')
      expect(html).to include(meal_path(potato_bar))
      expect(html).not_to include(meal_path(potato_salad))
    end

    it "finds meals by menu and shows the matching menu as the excerpt" do
      create(:meal, :with_menu, title: "Sunday supper", entrees: "Mushroom lasagna")
      refresh_indices
      expect(gather_search("lasagna")).to include("Mushroom <mark>lasagna</mark>")
    end

    it "finds memorials by name and obituary" do
      person = create(:user, first_name: "Ingrid", last_name: "Okafor")
      create(:memorial, user: person, birth_year: 1938, death_year: 2024, obituary: "A tireless gardener.")
      refresh_indices
      expect(gather_search("Okafor")).to include("1938–2024")
      expect(gather_search("gardener")).to include("tireless <mark>gardener</mark>")
    end
  end

  describe "result details", search: SearchController::GATHER_MODELS do
    it "shows a one-off event's date, without the time, and its calendar" do
      calendar = create(:calendar, name: "Common House")
      create(:event, name: "Quilting bee", calendar: calendar,
        starts_at: Time.zone.parse("2026-11-03 19:00"), ends_at: Time.zone.parse("2026-11-03 21:00"))
      refresh_indices
      expect(gather_search("quilting")).to include("Event · Nov 03 2026 · Common House")
    end

    it "shows a multi-day event's date range" do
      create(:event, name: "Garden retreat",
        starts_at: Time.zone.parse("2026-11-03 19:00"), ends_at: Time.zone.parse("2026-11-05 12:00"))
      refresh_indices
      expect(gather_search("retreat")).to include("Nov 03 2026 – Nov 05 2026")
    end

    it "shows a repeating event's pattern without the time" do
      create(:event, name: "Choir practice", recurrence_rule: IceCube::Rule.weekly.to_hash,
        starts_at: Time.zone.parse("2026-11-04 19:00"), ends_at: Time.zone.parse("2026-11-04 20:00"))
      refresh_indices
      html = gather_search("choir")
      expect(html).to include("Weekly on Wednesdays from Nov 04")
      expect(html).not_to include("7:00pm")
    end

    it "shows a meal's time, location and head cook" do
      cook = create(:user, first_name: "Rosa", last_name: "Ibarra")
      meal = create(:meal, :with_menu, title: "Tamale night", head_cook: cook)
      refresh_indices
      html = gather_search("tamale")
      expect(html).to include(CGI.escapeHTML(meal.decorate.served_at_datetime))
      expect(html).to include("Head cook: Rosa Ibarra")
    end

    it "shows a transaction's date, amount and household" do
      household = create(:household, name: "Okonkwo")
      account = Billing::Account.find_or_create_by!(household: household, community: community)
      create(:transaction, account: account, description: "Firewood", value: 12.5, incurred_on: "2026-10-01")
      refresh_indices
      sign_in(create(:biller)) # Only billers can see another household's transactions.
      html = gather_search("firewood")
      expect(html).to include("$12.50")
      expect(html).to include("Okonkwo household")
    end

    it "shows a pet's color, species and household" do
      create(:pet, name: "Biscuit", species: "Beagle", color: "Tan",
        household: create(:household, name: "Lund"))
      refresh_indices
      expect(gather_search("biscuit")).to include("Tan Beagle · Lund household")
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
