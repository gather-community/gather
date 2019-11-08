# frozen_string_literal: true

require "rails_helper"

describe "signups", js: true, clean_with_transaction: false do
  include_context "work"
  include_context "with jobs"

  let(:actor) { create(:user, first_name: "Alpha", last_name: "Smith") }
  let!(:partner) { create(:user, first_name: "Bravo", last_name: "Smith", household: actor.household) }
  let!(:friend) { create(:user, first_name: "Charlie", last_name: "Jenkins", job_choosing_proxy: actor) }
  let!(:other_user) { create(:user, first_name: "Delta", last_name: "Fu") }
  let!(:job) { create(:work_job, period: periods[0], shift_slots: 3) }
  let!(:shares) { [actor, partner, friend].each { |u| periods[0].shares.create!(user: u, portion: 1) } }

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  scenario "choosing as self and other" do
    visit(work_shifts_path)
    signup_and_expect_name(actor)
    choose_as(partner)
    signup_and_expect_name(partner)
    choose_as(friend)
    signup_and_expect_name(friend)
    choose_as(actor)
  end

  scenario "when actor removed as proxy" do
    visit(work_shifts_path)
    choose_as(friend)

    # Remove actor as friend's proxy
    friend.update!(job_choosing_proxy_id: nil)

    page.refresh

    expect(page).not_to have_css(".choosee-lens select", text: "Choosing as #{friend.name}")
    expect(page).not_to have_content("Choosing as #{friend.name}")
  end

  scenario "with legal user_id in query string" do
    visit(work_shifts_path(choosee: friend.id))
    expect(page).to have_content("You are choosing as #{friend.name}")
  end

  scenario "with illegal user_id in query string" do
    visit(work_shifts_path(choosee: other_user.id))
    expect(page).not_to have_content(other_user.name)
  end

  def choose_as(user)
    find(".choosee-lens").select("Choosing as #{user.name}")
    expect(page).to have_content("You are choosing as #{user.name}") unless user == actor
  end

  def signup_and_expect_name(user)
    within(".shift-card[data-id='#{job.shifts[0].id}']") do
      expect(page).not_to have_content(user.name)
      click_on("Sign Up!")
      expect(page).to have_content(user.name)
    end
  end
end
