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

  def expect_plain_dropdown(id:, default_opt:, opt2:)
    visit(path)

    # Initially, nothing should be selected, so the default option should be showing.
    expect(page).not_to have_css(".lens-bar ##{id} option[selected]")
    expect(first(".lens-bar ##{id} option")).to have_content(default_opt)

    # Select the secondary option, wait for page to load, and test.
    first(".lens-bar ##{id}").select(opt2[0])
    expect(page).to have_echoed_url(%r{(&|\?)#{id}=#{opt2[1]}(&|\z)})
    expect(first(".lens-bar ##{id}").find("option[selected]").text).to eq opt2[0]

    expect_rewritten_link_and_session(key: id, value: opt2[1]) do
      expect(first(".lens-bar ##{id}").find("option[selected]").text).to eq opt2[0]
    end
  end

  def expect_community_dropdown
    visit(path)
    expect(first(".lens-bar #community").find("option[selected]").text).to eq "Community 3"
    first(".lens-bar #community").select("Community 2")
    expect(page).to have_echoed_url(%r{\Ahttp://community2\.})
    expect(first(".lens-bar #community").find("option[selected]").text).to eq "Community 2"
  end

  def expect_search
    visit(path)
    expect(first(".lens-bar #search").text).to eq ""
    first(".lens-bar #search").set("foo")
    first(".lens-bar #search").native.send_keys(:return)
    expect(page).to have_echoed_url(%r{(&|\?)search=foo(&|\z)})
    expect(first(".lens-bar #search").value).to eq "foo"
    expect_rewritten_link_and_session(key: "search", value: "foo") do
      expect(first(".lens-bar #search").value).to eq "foo"
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
end
