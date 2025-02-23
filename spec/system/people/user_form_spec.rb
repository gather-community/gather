# frozen_string_literal: true

require "rails_helper"

describe "user form", js: true, perform_jobs: true do
  include_context "photo uploads"

  let(:admin) { create(:admin) }
  let(:photographer) { create(:photographer) }
  let(:user) { create(:user, :with_photo) }
  let!(:household) { create(:household, name: "Gingerbread") }
  let!(:household2) { create(:household, name: "Potatoheads") }
  let(:edit_path) { edit_user_path(user) }

  before do
    use_user_subdomain(actor)
    login_as(actor, scope: :user)
  end

  shared_examples_for "editing user" do
    scenario "edit user without changing email" do
      visit(edit_path)
      expect_image_upload(state: :existing, path: /cooper/)
      drop_in_dropzone(fixture_file_path("chomsky.jpg"))
      expect_image_upload(state: :new)
      fill_in("First Name", with: "Zoor")
      email_sent = email_sent_by do
        click_button("Save")
        expect(page).to have_alert(/updated successfully/)
      end
      expect(page).not_to have_field("User is a child?") unless actor.has_role?(:admin)

      expect(email_sent).to be_empty
      expect(page).to have_title(/Zoor/)
      expect_photo(/chomsky/)
      expect(user.reload.unconfirmed_email).to be_nil
    end

    scenario "edit user email" do
      visit(edit_path)
      fill_in("Email Address", with: "newone@example.com")
      email_sent = email_sent_by do
        click_button("Save")
        expect(page).to have_alert(/confirm (your|their) new email address/)
      end

      expect(email_sent.map(&:subject)).to eq(["Please Confirm Your Email Address"])
      expect(email_sent[0].body.encoded).to match(/security measure/)
      expect(user.reload).to be_confirmed
      expect(user.unconfirmed_email).to eq("newone@example.com")
    end
  end

  context "as admin" do
    let(:actor) { admin }

    it_behaves_like "photo upload widget"

    context "creating" do
      scenario "new adult" do
        visit(users_path)
        find(".btn .fa-plus").click
        click_on("Create Adult")

        expect(page).to have_field("User is a child?", checked: false)
        expect(page).not_to have_field("User should have full access to the system?")
        expect_full_access_fields(true)
        expect(page).not_to have_content("Guardians")

        expect_no_image_and_drop_file("cooper.jpg")
        click_button("Save")

        email_sent = email_sent_by do
          expect_validation_error
          expect_image_upload(state: :existing, path: /cooper/)
          fill_in("First Name", with: "Foo")
          fill_in("Last Name", with: "Barre")
          fill_in("Email Address", with: "foo@example.com")
          select2("Ginger", from: "#user_household_id")
          fill_in("Mobile", with: "5556667777")
          click_button("Save")

          expect(page).to have_alert("User created successfully.")
          expect(page).to have_title(/Foo Barre/)
          expect_photo(/cooper/)
        end

        expect(email_sent).to be_empty
        expect(User.find_by(email: "foo@example.com")).not_to be_confirmed
      end

      scenario "new child" do
        visit(users_path)
        find(".btn .fa-plus").click
        click_on("Create Child")
        expect(page).to have_field("User is a child?", checked: true)
        expect(page).to have_field("User should have full access to the system?", checked: false)
        expect_full_access_fields(false)
        expect(page).to have_content("Guardians")
        check("User should have full access to the system?")
        expect_full_access_fields(true)
        expect(page).to have_content("Guardians")
      end

      scenario "new user with invite" do
        email_sent = email_sent_by do
          visit(new_user_path)
          fill_in("First Name", with: "Foo")
          fill_in("Last Name", with: "Barre")
          fill_in("Email Address", with: "foo@example.com")
          select2("Ginger", from: "#user_household_id")
          fill_in("Mobile", with: "5556667777")
          click_on("Save & Invite")

          expect(page).to have_alert("User created and invited successfully.")
        end

        expect(email_sent.map(&:subject)).to eq(["Instructions for Signing in to Gather"])
        expect(User.find_by(email: "foo@example.com")).not_to be_confirmed
      end

      context "with custom fields" do
        let(:community_with_user_custom_fields) do
          create(:community, settings: {
            people: {
              user_custom_fields_spec: "- key: foo\n  " \
                                       "type: boolean\n" \
                                       "- key: bar\n  " \
                                       "type: string\n  " \
                                       "label: Pants\n    " \
                                       "hint: Pants information"
            }
          })
        end
        let!(:actor) { create(:admin, community: community_with_user_custom_fields) }
        let!(:household) { create(:household, name: "Qux", community: community_with_user_custom_fields) }

        scenario "allows entry of custom fields" do
          visit(new_user_path)
          fill_in("First Name", with: "Foo")
          fill_in("Last Name", with: "Barre")
          fill_in("Email Address", with: "foo@example.com")
          select2("Qux", from: "#user_household_id")
          fill_in("Mobile", with: "5556667777")

          check("Foo")
          fill_in("Pants", with: "blah")

          click_button("Save")
          expect(page).to have_alert("User created successfully.")

          # Check that the boolean value got persisted properly, which shows that normalizations ran.
          expect(page).to have_content(/Foo\s+Yes/)
          expect(page).to have_content(/Pants\s+blah/)
        end
      end
    end

    context "editing" do
      context "with adult" do
        it_behaves_like "editing user"

        scenario "editing household" do
          visit(edit_path)
          click_on("move them to another household")
          select2("Potatoheads", from: "#user_household_id")
          click_button("Save")

          expect_success
          expect(page).to have_css(%(a.household[href$="/households/#{household2.id}"]))
        end

        context "with unconfirmed user" do
          let(:user) { create(:user, :unconfirmed) }

          shared_examples_for "editing email does not result in confirmation email" do
            scenario do
              visit(edit_path)
              fill_in("Email Address", with: "newone@example.com")
              email_sent = email_sent_by do
                click_button("Save")
                expect(page).to have_alert(alert)
              end

              expect(email_sent).to be_empty
              expect(user.reload).not_to be_confirmed
              expect(user.unconfirmed_email).to be_nil
            end
          end

          context "with invite pending" do
            let(:alert) { /invalidated a sign-in invitation/ }

            before { user.reset_reset_password_token! }

            it_behaves_like "editing email does not result in confirmation email"
          end

          context "without invite pending" do
            let(:alert) { "User updated successfully." }

            it_behaves_like "editing email does not result in confirmation email"
          end
        end
      end

      context "with child" do
        let!(:user) { create(:user, :child) }

        scenario "changing household" do
          visit(edit_path)
          select2("Potatoheads", from: "#user_household_id")
          click_button("Save")

          expect_success
          expect(page).to have_css(%(a.household[href$="/households/#{household2.id}"]))
        end

        scenario "changing to full access" do
          visit(edit_path)
          check("User should have full access to the system?")
          expect_full_access_fields(true)
          expect(page).to have_content("Guardians")

          click_button("Save")
          expect(page).to have_content("Age certification is required for children with full access")

          check("I certify that this user is 13 years of age or older")
          click_button("Save")
          expect_success
          expect(page).to have_content("This address has not yet been confirmed")
        end

        scenario "changing to adult" do
          visit(edit_path)
          uncheck("User is a child?")
          expect_full_access_fields(true)
          expect(page).not_to have_content("Guardians")
          expect(page).not_to have_field("User should have full access to the system?")

          click_button("Save")
          expect(page).to have_content("Age certification is required for changing child to adult")

          check("I certify that this user is 13 years of age or older")
          click_button("Save")
          expect_success
          expect(page).to have_content("This address has not yet been confirmed")
        end
      end

      context "with custom fields" do
        let(:community_with_user_custom_fields) do
          create(:community, settings: {
            people: {
              user_custom_fields_spec: "- key: foo\n  " \
                                       "type: boolean\n" \
                                       "- key: bar\n  " \
                                       "type: string\n  " \
                                       "label: Pants\n    " \
                                       "hint: Pants information"
            }
          })
        end
        let!(:user) { create(:user, community: community_with_user_custom_fields) }
        let!(:actor) { create(:admin, community: community_with_user_custom_fields) }

        scenario "allows entry of custom fields" do
          visit(edit_path)
          expect(page).to have_content("Pants information")
          check("Foo")
          fill_in("Pants", with: "blah")
          click_button("Save")

          expect_success

          # Check that the boolean value got persisted properly, which shows that normalizations ran.
          expect(page).to have_content(/Foo\s+Yes/)

          click_on("Edit")
          expect(page).to have_field("Foo", checked: true)
          expect(page).to have_field("Pants", with: "blah")
        end
      end
    end

    scenario "deactivate/activate/delete with email" do
      visit(edit_path)
      accept_confirm { click_on("Deactivate") }
      expect_success

      visit(edit_path)
      click_link("reactivate")
      expect_success("User activated successfully.")

      visit(edit_path)
      expect(page).not_to have_content("reactivate")
      accept_confirm { click_on("Delete") }
      expect_success

      expect { user.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    scenario "deactivate, remove email, add email, reactivate" do
      visit(edit_path)
      accept_confirm { click_on("Deactivate") }
      expect_success

      visit(edit_path)
      fill_in("Email Address", with: "")
      click_button("Save")
      expect_success

      visit(edit_path)
      click_link("reactivate")
      expect(page).to have_danger_alert("Error during activation: Email Address can't be blank")
      fill_in("Email Address", with: "foobar@example.com")
      click_button("Save")
      expect_success

      visit(edit_path)
      click_link("reactivate")
      expect(page).to have_warning_alert("User activated successfully, but they will need an invitation to sign in. " \
                                         "Click 'Invite' below to invite them.")
    end
  end

  context "as photographer" do
    let(:actor) { photographer }

    scenario "update photo" do
      visit(user_path(user))
      click_on("Edit Photo")
      expect_image_upload(state: :empty)
      drop_in_dropzone(fixture_file_path("chomsky.jpg"))
      expect_image_upload(state: :new)
      click_button("Save")
      expect_success
      expect_photo(/chomsky/)
    end
  end

  context "as regular user" do
    let(:actor) { user }

    it_behaves_like "editing user"

    context "when editing child" do
      let!(:child) { create(:user, :child, guardians: [actor]) }

      scenario do
        visit(edit_user_path(child))
        expect(page).not_to have_field("User is a child?")
        fill_in("First Name", with: "Lorp")
        click_on("Save")

        expect_success
        expect(page).to have_content("Lorp")
      end
    end
  end

  def expect_full_access_fields(whether)
    if whether
      expect(page).to have_field("Google ID")
      expect(page).to have_field("Admin")
    else
      expect(page).not_to have_field("Google ID")
      expect(page).not_to have_field("Admin")
    end
  end
end
