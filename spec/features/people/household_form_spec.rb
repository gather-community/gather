require "rails_helper"

feature "household form" do
  around do |example|
    with_user_home_subdomain(actor) { example.run }
  end

  before do
    login_as(actor, scope: :user)
  end

  describe "create" do
    shared_examples_for "creates household" do |community_name|
      scenario "new household", js: true do
        visit(new_household_path)
        fill_in("Household Name", with: "Pump")
        select(community_name, from: "Community") if community_name
        fill_in("Unit Number", with: "33")
        fill_in("Garage Number(s)", with: "7")
        click_on("Create Household")
        expect_success
        select(community_name, from: "community") if community_name
        click_on("Pump")
        expect(page).to have_css("table.key-value", text: community_name) if community_name
      end
    end

    context "as admin with single community" do
      let(:actor) { create(:admin) }
      it_behaves_like "creates household"
    end

    context "as cluster admin with multiple communities" do
      let!(:actor) { create(:cluster_admin) }
      let!(:other_community) { create(:community, name: "Foo") }
      it_behaves_like "creates household", "Foo"
    end
  end

  describe "update" do
    let(:user) { create(:user) }
    let(:admin) { create(:admin) }

    shared_examples_for "updates household" do
      scenario js: true do
        visit(edit_household_path(user.household))
        fill_in("Name *", with: "Lori", exact: true)
        fill_in("Relationship to Household", with: "Mom")
        fill_in("Main Phone", with: "7776665555")
        fill_in("Location", with: "Placey Place")
        click_button("Update Household")
        expect(page).to have_content("updated successfully")
      end
    end

    context "with single community" do
      context "as basic user" do
        let!(:actor) { user }
        it_behaves_like "updates household"
      end

      context "as admin" do
        let!(:actor) { admin }
        it_behaves_like "updates household"
      end
    end

    context "with multiple communities" do
      let!(:other_community) { create(:community, name: "Foo") }

      context "as basic user" do
        let!(:actor) { user }
        it_behaves_like "updates household"
      end

      context "as admin" do
        let!(:actor) { admin }
        it_behaves_like "updates household"
      end
    end
  end
end
