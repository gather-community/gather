# frozen_string_literal: true

require "rails_helper"

feature "lenses", js: true do
  let!(:community1) { Defaults.community }
  let!(:community2) { create(:community, name: "Community 2", slug: "community2") }
  let!(:community3) { create(:community, name: "Community 3", slug: "community3") }
  let!(:user) { create(:user, community: community3) }

  around { |ex| with_user_home_subdomain(user) { ex.run } }

  before do
    login_as(user, scope: :user)
  end

  describe "plain select lens" do
    scenario "life stage" do
      visit(users_path)
      expect_select_lens(param_name: :lifestage, default_opt: "Adults + Children",
                         opt2: %w[Adults adult], path: users_path, nav_link: "People")
    end
  end

  describe "community lens (highly customized)" do
    context "basic" do
      scenario do
        visit(users_path)
        expect(lens_selected_option(:community).text).to eq("Community 3")
        lens_field(:community).select("Community 2")
        expect(page).to have_echoed_url(%r{\Ahttp://community2\.})
        expect(lens_selected_option(:community).text).to eq("Community 2")
        expect(page).not_to have_css(".lens-bar a.clear")
      end
    end

    context "with all option" do
      scenario do
        visit(meals_path)

        expect_unselected_option(lens_selector(:community), "All Communities")
        lens_field(:community).select("Community 2")

        expect(page).to have_echoed_url(%r{\Ahttp://community2\.})
        expect(lens_selected_option(:community).text).to eq("Community 2")
        expect(page).to have_echoed_url_param("community", "this")
        # Clear button should work for all option mode only
        first(".lens-bar a.clear").click

        expect(page).to have_echoed_url_param("community", "")
        expect_unselected_option(lens_selector(:community), "All Communities")
      end
    end

    context "with no subdomain change" do
      before do
        [community1, community2, community3].each do |c|
          create(:account, community: c, household: user.household)
        end
      end

      scenario do
        visit(accounts_household_path(user.household))
        expect(lens_selected_option(:community).text).to eq("Community 3")

        lens_field(:community).select("Community 2")

        expect(page).to have_echoed_url(%r{\Ahttp://community3\.})
        expect(page).to have_echoed_url_param("community", "community2")
        expect(lens_selected_option(:community).text).to eq("Community 2")
        expect(page).not_to have_css(".lens-bar a.clear")
        visit(accounts_household_path(user.household))

        expect(page).to have_echoed_url(accounts_household_path(user.household))
        expect(lens_selected_option(:community).text).to eq("Community 2")
      end
    end
  end

  describe "search lens" do
    scenario "search" do
      visit(users_path)
      expect_search(path: users_path, nav_link: "People")
    end
  end

  describe "global lens" do
    let!(:period1) do
      create(:work_period, community: user.community, name: "Period 1",
                           phase: "published", starts_on: 5.days.ago)
    end
    let!(:period2) do
      create(:work_period, community: user.community, name: "Period 2",
                           phase: "published", starts_on: 100.days.ago)
    end

    scenario "period" do
      visit(work_shifts_path)
      expect(lens_selected_option(:period).text).to eq("Period 1")

      # Select Period 2 and wait.
      select_lens_and_wait("period", "Period 2")
      expect(lens_selected_option(:period).text).to eq("Period 2")

      # Should be selected on other work pages too.
      visit(work_jobs_path)
      expect(page).to have_echoed_url(%r{work/jobs})
      expect(lens_selected_option(:period).text).to eq("Period 2")
    end
  end

  describe "floating lens" do
    let!(:user2) { create(:user, household: user.household) }
    let!(:period1) do
      create(:work_period, community: user.community, name: "Period 1",
                           phase: "published", starts_on: 5.days.ago)
    end

    before do
      [user, user2].each { |u| create(:work_share, period: period1, user: u) }
    end

    scenario "is not in the lens bar" do
      visit(work_shifts_path)
      expect(page).not_to have_css("form.lens-bar .choosee-lens")
      expect(page).to have_css("form.floating-lens .choosee-lens")
    end
  end

  describe "inter-community behavior" do
    scenario "separate lenses per-community" do
      visit(users_path) # community3
      fill_in_lens_and_wait(:search, "foo")
      with_subdomain("default") do
        visit(users_path)
        expect_lens_value(:search, "")
      end
    end
  end

  #####################################################################################################
  # TODO: The rest of these specs should be moved into domain-specific spec files.
  # They don't contribute coverage of the code in the Lens namespace. But for now, they are at least
  # exercising some endpoints that aren't otherwise exercised.
  # When these are moved, they should be replaced with specs that actually test the semantics of the
  # lenses (e.g. that adults-only are actually displayed when you pick that from the lens.)
  # There is no need to test e.g. the basic select lens behavior over and over.
  # Lenses that are more custom, though, like choosee lens, deserve a bit more coverage.

  describe "directory lenses" do
    scenario "user sort" do
      visit(users_path)
      expect_select_lens(param_name: :sort, default_opt: "By Name",
                         opt2: ["By Unit", "unit"], path: users_path, nav_link: "People")
    end

    scenario "user view" do
      visit(users_path)
      expect_select_lens(param_name: :view, default_opt: "Album",
                         opt2: %w[Table table], path: users_path, nav_link: "People")
    end
  end

  describe "meals lens" do
    scenario "community" do
      visit(meals_path)
      expect_community_dropdown(all_option: true)
    end

    scenario "time" do
      visit(meals_path)
      expect_select_lens(param_name: :time, default_opt: "Upcoming",
                         opt2: %w[Past past], path: meals_path, nav_link: "Meals")
    end

    scenario "search" do
      visit(meals_path)
      expect_search(path: meals_path, nav_link: "Meals")
    end
  end

  describe "reservation lens" do
    scenario "community" do
      visit(reservations_path)
      expect_community_dropdown
    end
  end

  describe "my accounts lens" do
    before do
      [community1, community2, community3].each do |c|
        create(:account, community: c, household: user.household)
      end
    end

    scenario "community" do
      visit(accounts_household_path(user.household))
      # This kind of community drop-down does not change the subdomain.
      expect_community_dropdown(subdomain: false)
    end
  end

  def expect_select_lens(param_name:, default_opt:, opt2:, path:, nav_link:)
    # Nothing should be initially selected, so the default option should be showing.
    expect_unselected_option(lens_selector(param_name), default_opt)

    # Select the secondary option, wait for page to load, and test.
    select_lens_and_wait(param_name, opt2[0])
    expect(lens_selected_option(param_name).text).to eq(opt2[0])

    expect_rewritten_link_and_session(key: param_name, value: opt2[1], path: path, nav_link: nav_link) do
      expect(lens_selected_option(param_name).text).to eq(opt2[0])
    end
  end

  def expect_community_dropdown(all_option: false, subdomain: true)
    # Save URL before we change
    orig_url = current_url

    # If lens includes 'All Communites' option, that should be default.
    # Otherwise user's home cmty should be default.
    if all_option
      expect_unselected_option(lens_selector(:community), "All Communities")
    else
      expect(lens_selected_option(:community).text).to eq("Community 3")
    end
    lens_field(:community).select("Community 2")

    # If the lens changes the subdomain, check for that.
    # Else check for QS param.
    if subdomain
      expect(page).to have_echoed_url(%r{\Ahttp://community2\.})
    else
      expect(page).to have_echoed_url_param("community", "community2")
    end

    # Check for correct selected param.
    expect(lens_selected_option(:community).text).to eq("Community 2")

    if all_option
      expect(page).to have_echoed_url_param("community", "this")
      # Clear button should work for all option mode only
      first(".lens-bar a.clear").click
      expect(page).to have_echoed_url_param("community", "")
      expect_unselected_option(lens_selector(:community), "All Communities")
    else
      expect(page).not_to have_css(".lens-bar a.clear")
    end

    # Direct path visit should maintain value in subdomain mode only.
    unless subdomain
      visit(orig_url)
      expect(page).to have_echoed_url(orig_url)
      expect(lens_selected_option(:community).text).to eq("Community 2")
    end
  end

  def expect_search(path:, nav_link:)
    expect(lens_field(:search).text).to eq("")
    fill_in_lens_and_wait(:search, "foo")
    expect(lens_field(:search).value).to eq("foo")
    expect_rewritten_link_and_session(key: "search", value: "foo", path: path, nav_link: nav_link) do
      expect(lens_field(:search).value).to eq("foo")
    end
  end

  def expect_rewritten_link_and_session(key:, value:, path:, nav_link:)
    # Click away, check the rewritten link, and come back.
    find(".dropdown a", text: user.name).click
    click_link("Profile")
    expect(page).to have_content(user.name)
    expect(page).to have_css(".main-nav a[href^='#{path}?#{key}=#{value}']")
    find(".main-nav a", text: nav_link).click
    yield

    # Direct path visit
    visit(path)
    expect(page).to have_echoed_url(/#{path}\z/)
    yield
  end

  def lens_selected_option(param_name)
    lens_field(param_name).find("option[selected]")
  end

  def lens_field(param_name)
    first(lens_selector(param_name))
  end

  def lens_selector(param_name)
    ".#{param_name.to_s.dasherize}-lens"
  end
end
