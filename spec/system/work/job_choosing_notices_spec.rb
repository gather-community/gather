# frozen_string_literal: true

require "rails_helper"

# The page where a coordinator previews the job choosing notices before sending them.
describe "job choosing notices" do
  let(:actor) { create(:admin) }
  let(:period) { create(:work_period, phase: "ready", quota_type: "by_person") }
  let(:english) { create(:user) }
  let(:german) { create(:user, locale: "de") }

  before do
    create(:feature_flag, name: "i18n", status: true)
    create(:work_share, period: period, user: english)
    create(:work_share, period: period, user: german)
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  scenario "previews each notice in the language its recipient will get it in" do
    visit(review_notices_work_period_path(period))
    expect(page).to have_content("Job choosing is coming up soon!")
    expect(page).to have_content("Die Aufgabenwahl beginnt bald!")
  end
end
