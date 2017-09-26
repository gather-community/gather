require "rails_helper"

feature "lenses", js: true do
  let!(:community1) { create(:community, name: "Community 1", slug: "community1") }
  let!(:community2) { create(:community, name: "Community 2", slug: "community2") }
  let!(:community3) { create(:community, name: "Community 3", slug: "community3") }
  let!(:user) { create(:user, community: community3) }

  around { |ex| with_user_home_subdomain(user) { ex.run } }

  before do
    login_as(user, scope: :user)
  end

  describe "directory lens" do
    let(:path) { users_path }
    let(:nav_link) { "People"}

    scenario "community" do
      expect_community_dropdown
    end

    scenario "life stage" do
      expect_plain_dropdown(id: "life_stage", default_opt: "Adults + Children", opt2: ["Adults", "adult"])
    end

    scenario "user sort" do
      expect_plain_dropdown(id: "user_sort", default_opt: "By Name", opt2: ["By Unit", "unit"])
    end

    scenario "user view" do
      expect_plain_dropdown(id: "user_view", default_opt: "Album", opt2: ["Table", "table"])
    end

    scenario "search" do
      expect_search
    end
  end

  describe "meals lens" do
    let(:path) { meals_path }
    let(:nav_link) { "Meals"}

    scenario "community" do
      expect_community_dropdown(all_option: true)
    end

    scenario "time" do
      expect_plain_dropdown(id: "time", default_opt: "Upcoming", opt2: ["Past", "past"])
    end

    scenario "search" do
      expect_search
    end
  end

  describe "reservation lens" do
    let(:path) { reservations_path }
    let(:nav_link) { "Reservations"}

    scenario "community" do
      expect_community_dropdown
    end
  end

  describe "my accounts lens" do
    let(:path) { accounts_household_path(user.household) }

    before do
      [community1, community2, community3].each do |c|
        create(:account, community: c, household: user.household)
      end
    end

    scenario "community" do
      # This kind of community drop-down does not change the subdomain.
      expect_community_dropdown(subdomain: false)
    end
  end

  def expect_plain_dropdown(id:, default_opt:, opt2:)
    visit(path)

    # Initially, nothing should be selected, so the default option should be showing.
    expect_unselected_option(".lens-bar ##{id}", default_opt)

    # Select the secondary option, wait for page to load, and test.
    lens_field(id).select(opt2[0])
    expect(page).to have_echoed_url(%r{(&|\?)#{id}=#{opt2[1]}(&|\z)})
    expect(lens_selected_option(id).text).to eq opt2[0]

    expect_rewritten_link_and_session(key: id, value: opt2[1]) do
      expect(lens_selected_option(id).text).to eq opt2[0]
    end
  end

  def expect_community_dropdown(all_option: false, subdomain: true)
    visit(path)
    if all_option
      expect_unselected_option(".lens-bar #community", "All Communities")
    else
      expect(lens_selected_option("community").text).to eq "Community 3"
    end
    lens_field("community").select("Community 2")
    if subdomain
      expect(page).to have_echoed_url(%r{\Ahttp://community2\.})
    else
      expect(page).to have_echoed_url(%r{(&|\?)community=community2(&|\z)})
    end
    expect(lens_selected_option("community").text).to eq "Community 2"
    if all_option
      expect(page).to have_echoed_url(%r{(&|\?)community=this(&|\z)})

      # Clear button should work for all option mode only
      first(".lens-bar a.clear").click
      expect(page).to have_echoed_url(%r{(&|\?)community=(&|\z)})
      expect_unselected_option(".lens-bar #community", "All Communities")
    else
      expect(page).not_to have_css(".lens-bar a.clear")
    end

    # Direct path visit should maintain value in subdomain mode only.
    unless subdomain
      visit(path)
      expect(page).to have_echoed_url(%r{#{path}\z})
      expect(lens_selected_option("community").text).to eq "Community 2"
    end
  end

  def expect_search
    visit(path)
    expect(lens_field("search").text).to eq ""
    lens_field("search").set("foo")
    lens_field("search").native.send_keys(:return)
    expect(page).to have_echoed_url(%r{(&|\?)search=foo(&|\z)})
    expect(lens_field("search").value).to eq "foo"
    expect_rewritten_link_and_session(key: "search", value: "foo") do
      expect(lens_field("search").value).to eq "foo"
    end
  end

  def expect_rewritten_link_and_session(key:, value:)
    # Click away, check the rewritten link, and come back.
    find(".dropdown a", text: user.name).click
    click_link("Profile")
    expect(page).to have_content(user.name)
    expect(page).to have_css(".main-nav a[href^='#{path}?#{key}=#{value}']")
    find(".main-nav a", text: nav_link).click
    yield

    # Direct path visit
    visit(path)
    expect(page).to have_echoed_url(%r{#{path}\z})
    yield
  end

  def lens_selected_option(id)
    lens_field(id).find("option[selected]")
  end

  def lens_field(id)
    first(".lens-bar ##{id}")
  end
end
