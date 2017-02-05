require "rails_helper"

feature "household form" do
  shared_examples_for "creating household" do |community_name|
    before do
      login_as(admin, scope: :user)
    end

    scenario "new household", js: true do
      visit(new_household_path)
      fill_in("Household Name", with: "Pump")
      select(community_name, from: "Community") if community_name
      fill_in("Unit Number", with: "33")
      fill_in("Garage Number(s)", with: "7")
      click_on("Create Household")
      expect_success
      click_on("Pump")
      expect(page).to have_css("table.key-value", text: community_name) if community_name
    end
  end

  context "as admin" do
    let(:admin) { create(:admin) }
    it_behaves_like "creating household"
  end

  context "as cluster admin" do
    let!(:admin) { create(:cluster_admin) }
    let!(:other_community) { create(:community, name: "Foo", cluster: admin.cluster) }
    it_behaves_like "creating household", "Foo"
  end
end
