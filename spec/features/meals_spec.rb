require "rails_helper"

feature "meals" do
  let(:user) { create(:user) }
  let(:cmty) { user.community }
  let(:friend_cmty) { create(:community, cluster: cmty.cluster) }
  let(:other_cmty) { create(:community, cluster: create(:cluster)) }
  let!(:own_meals) { create_list(:meal, 3, host_community: cmty) }
  let!(:friend_meals) { create_list(:meal, 2, host_community: friend_cmty,
    communities: [cmty, friend_cmty]) }
  let!(:other_meal) { create(:meal, :with_menu, host_community: other_cmty, title: "Flapjacks") }

  around do |example|
    with_user_home_subdomain(user) { example.run }
  end

  before do
    login_as(user, scope: :user)
  end

  scenario "index" do
    visit "/meals"
    expect(page).not_to have_content("Flapjacks")
    expect(page).to have_css("table.index tbody tr", count: 5)
  end
end
