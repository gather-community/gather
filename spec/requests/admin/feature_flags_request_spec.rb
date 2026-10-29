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
    def search(query)
      get(user_search_admin_feature_flag_path(flag), params: {q: query})
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

    it "leaves out users already on the flag" do
      flag.users << jane
      expect(search("jane").pluck("name")).to contain_exactly("Janet Smith", "Jane Far")
    end

    it "returns nothing for a query that's too short" do
      expect(search("j")).to eq([])
    end
  end

  describe "update" do
    it "changes only the mode" do
      patch(admin_feature_flag_path(flag), params: {feature_flag: {mode: "everyone", name: "renamed"}})
      expect(response).to redirect_to(admin_feature_flag_path(flag))
      expect(flag.reload.mode).to eq(:everyone)
      expect(flag.name).to eq("messaging")
    end
  end

  describe "user management" do
    it "adds a user from another cluster, and adding twice is harmless" do
      2.times { post(admin_feature_flag_users_path(flag), params: {user_id: far_user.id}) }
      expect(response).to redirect_to(admin_feature_flag_path(flag))
      # Users span clusters, so read them without a tenant.
      ActsAsTenant.without_tenant { expect(flag.reload.users).to eq([far_user]) }
    end

    it "removes a user" do
      flag.users << jane
      delete(admin_feature_flag_user_path(flag, jane))
      expect(response).to redirect_to(admin_feature_flag_path(flag))
      ActsAsTenant.without_tenant { expect(flag.reload.users).to be_empty }
    end
  end

  context "as a cluster admin" do
    let!(:actor) { create(:cluster_admin) }

    it "forbids the index" do
      expect { get(admin_feature_flags_path) }.to raise_error(Pundit::NotAuthorizedError)
    end

    it "forbids the user search" do
      expect { get(user_search_admin_feature_flag_path(flag), params: {q: "jane"}) }
        .to raise_error(Pundit::NotAuthorizedError)
    end

    it "forbids changing the mode" do
      expect { patch(admin_feature_flag_path(flag), params: {feature_flag: {mode: "everyone"}}) }
        .to raise_error(Pundit::NotAuthorizedError)
      expect(flag.reload.mode).to eq(:selected_users)
    end

    it "forbids adding users" do
      expect { post(admin_feature_flag_users_path(flag), params: {user_id: jane.id}) }
        .to raise_error(Pundit::NotAuthorizedError)
      ActsAsTenant.without_tenant { expect(flag.users).to be_empty }
    end
  end
end
