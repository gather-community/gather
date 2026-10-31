# frozen_string_literal: true

require "rails_helper"

# The browser flows are in spec/system/admin/feature_flags_spec.rb. This covers the JSON search
# endpoint's matching rules and the authorization checks.
describe "admin feature flags request" do
  let!(:actor) { create(:super_admin) }
  let!(:flag) { create(:feature_flag, name: "messaging", interface: "user") }
  let!(:jane) { create(:user, first_name: "Jane", last_name: "Doe", email: "jane@example.com") }
  let!(:janet) { create(:user, first_name: "Janet", last_name: "Smith", email: "jsmith@example.com") }
  let!(:inactive) { create(:user, :inactive, first_name: "Jane", last_name: "Gone") }
  let!(:other_cluster) { create(:cluster, name: "Other Cluster") }
  let!(:far_user) do
    with_tenant(other_cluster) do
      community = create(:community, name: "Far Community")
      create(:user, first_name: "Jane", last_name: "Far", email: "far@example.org", community: community)
    end
  end

  before do
    use_apex_domain
    sign_in(actor)
  end

  describe "user_search" do
    def search(query, exclude: nil)
      get(user_search_admin_feature_flags_path, params: {q: query, exclude: exclude}.compact)
      expect(response).to have_http_status(:ok)
      response.parsed_body["results"]
    end

    it "matches active users by name across clusters, with their community" do
      results = search("jane")
      expect(results.pluck("name")).to contain_exactly("Jane Doe", "Janet Smith", "Jane Far")
      far = results.find { |r| r["name"] == "Jane Far" }
      expect(far).to eq("id" => far_user.id, "name" => "Jane Far", "email" => "far@example.org",
        "community" => "Far Community")
    end

    it "matches by email" do
      expect(search("jsmith@").pluck("name")).to eq(["Janet Smith"])
    end

    it "treats LIKE wildcards literally" do
      expect(search("%%")).to eq([])
    end

    it "leaves out users already chosen on the form" do
      expect(search("jane", exclude: "#{jane.id},#{janet.id}").pluck("name")).to eq(["Jane Far"])
    end

    it "returns nothing for a query that's too short" do
      expect(search("j")).to eq([])
    end
  end

  describe "update" do
    it "can't rename the flag" do
      patch(admin_feature_flag_path(flag), params: {feature_flag: {mode: "everyone", name: "renamed"}})
      expect(response).to redirect_to(admin_feature_flag_path(flag))
      expect(flag.reload.mode).to eq(:everyone)
      expect(flag.name).to eq("messaging")
    end

    it "saves the chosen users, including one from another cluster" do
      flag.users << jane
      patch(admin_feature_flag_path(flag),
        params: {feature_flag: {mode: "selected_users", user_ids: ["", far_user.id.to_s]}})
      expect(response).to redirect_to(admin_feature_flag_path(flag))
      # Users span clusters, so read them without a tenant.
      ActsAsTenant.without_tenant { expect(flag.reload.users).to eq([far_user]) }
    end
  end

  context "as a cluster admin" do
    let!(:actor) { create(:cluster_admin) }

    it "forbids the index" do
      expect { get(admin_feature_flags_path) }.to raise_error(Pundit::NotAuthorizedError)
    end

    it "forbids the user search" do
      expect { get(user_search_admin_feature_flags_path, params: {q: "jane"}) }
        .to raise_error(Pundit::NotAuthorizedError)
    end

    it "forbids changing the mode" do
      expect { patch(admin_feature_flag_path(flag), params: {feature_flag: {mode: "everyone"}}) }
        .to raise_error(Pundit::NotAuthorizedError)
      expect(flag.reload.mode).to eq(:selected_users)
    end
  end
end
