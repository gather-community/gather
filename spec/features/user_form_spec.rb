require "rails_helper"

feature "calendar export" do
  let(:user) { create(:admin) }
  let!(:household) { create(:household, name: "Gingerbread") }

  before do
    login_as(user, scope: :user)
  end

  scenario "new user", js: true do
    visit(new_user_path)
    expect_image_upload(mode: :existing, path: /missing\/users/)
    drop_in_dropzone(fixture_file_path("cooper.jpg"))
    expect_image_upload(mode: :dz_preview)
    click_on("Create User")

    expect_validation_error
    expect_image_upload(mode: :existing, path: /cooper/)
    fill_in("First Name", with: "Foo")
    fill_in("Last Name", with: "Barre")
    fill_in("Email", with: "foo@example.com")
    select2("Ginger", from: "user_household_id")
    fill_in("Mobile Phone", with: "5556667777")
    click_on("Create User")

    expect_validation_success
    expect(page).to have_css("h1", text: /Foo Barre/)
    expect(page.find("img.photo")["src"]).to match /cooper/
  end
end
