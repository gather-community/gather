# frozen_string_literal: true

require "rails_helper"

feature "birthday list" do
  let(:actor) { create(:user) }

  around { |ex| with_user_home_subdomain(actor) { ex.run } }

  before do
    login_as(actor, scope: :user)
  end

  let!(:user1) { create(:user, birthday_str: "2000-04-05") }
  let!(:user2) { create(:user, birthday_str: "Oct 2") }
  let!(:user3) { create(:user, birthday_str: nil) }

  scenario "index" do
    visit(people_birthdays_path)
    expect(page).to have_title("Birthdays")
    expect(page).to have_content("Apr 05 2000")
    expect(page).to have_content("Oct 02")
    expect(page).to have_content("#{user3.first_name} #{user3.last_name} ?")
  end
end
