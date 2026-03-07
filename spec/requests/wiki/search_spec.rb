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

  describe "GET /wiki/search (JSON, wiki source)" do
    let(:fake_result) do
      double("ES result",
             title: "Solar Panels",
             slug: "solar-panels",
             highlight: nil,
             updated_at: 1.week.ago.iso8601)
    end
    let(:fake_results) { [fake_result] }

    before do
      allow(Wiki::Page).to receive(:search).and_return(
        instance_double(Elasticsearch::Model::Response::Response, results: fake_results)
      )
    end

    it "returns HTML fragment with wiki results" do
      get(wiki_search_path, params: {search: "solar", source: "wiki"},
                            headers: {"Accept" => "application/json"})
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["html"]).to include("Solar Panels")
      expect(json["next_page_token"]).to be_nil
    end
  end

  describe "GET /wiki/search (JSON, drive source)" do
    context "without gdrive config" do
      it "returns empty drive results" do
        get(wiki_search_path, params: {search: "solar", source: "drive"},
                              headers: {"Accept" => "application/json"})
        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["html"]).to include("No Drive files found")
        expect(json["next_page_token"]).to be_nil
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
