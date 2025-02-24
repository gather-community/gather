# frozen_string_literal: true

require "rails_helper"

describe People::CsvExporter do
  let(:policy) { UserPolicy.new(actor, User.new(household: Household.new(community: actor.community))) }
  let(:exporter) { described_class.new(User.by_name.active.where.not(id: actor.id), policy: policy) }

  describe "to_csv" do
    context "with no users" do
      let(:actor) { create(:user) }

      it "should return valid csv" do
        # Full headers are tested below.
        expect(exporter.to_csv).to match(/\A"ID",/)
      end

      context "with other locale" do
        it "should use locale specific headers" do
          with_locale(:fr) do
            expect(exporter.to_csv).to match(/,Prénom,/)
          end
        end
      end
    end

    context "with users" do
      let!(:household1) do
        create(:household, name: "Fun", member_count: 0, unit_num: "20", unit_suffix: "3A",
                           garage_nums: "4,9", keyholders: "Sally, Muhammad")
      end
      let!(:vehicle1) do
        create(:vehicle, household: household1, color: "Blue", make: "Ford",
                         model: "F-150", plate: "XYZ123")
      end
      let!(:vehicle2) do
        create(:vehicle, household: household1, color: "Red", make: "GMC",
                         model: "Jimmy", plate: "XYZ456")
      end
      let!(:contact1) do
        create(:emergency_contact,
               household: household1, alt_phone: "+17895550099", email: "j@k.com", location: "Anchorage",
               main_phone: "+15456736543", name: "Wei Lu", relationship: "Ron's Mother")
      end
      let!(:contact2) do
        create(:emergency_contact,
               household: household1, email: "l@n.com", location: "King's Landing",
               main_phone: "+15456736543", alt_phone: nil, name: "Spin Lok", relationship: "Close friend")
      end
      let!(:pet1) { create(:pet, household: household1, name: "Po", color: "Blue", species: "Snake") }
      let!(:pet2) { create(:pet, household: household1, name: "Wu", color: "Green", species: "Bird") }

      # Deliberately make first user lexically last to ensure sort respected.
      let!(:adult1) do
        create(:user, household: household1, first_name: "Ron", last_name: "South", email: "a@b.com",
                      birthdate: "1980/07/20", joined_on: "2016/03/12", preferred_contact: "email",
                      mobile_phone: "+17345556376", home_phone: "+17345551981")
      end
      let!(:adult2) do
        create(:user, :inactive, household: household1, first_name: "Jenn", last_name: "Blount", email: "c@d.com",
                                 birthdate: "0004/03/10", pronouns: "zey/zem", joined_on: "2016/08/01", deactivated_at: "2017-02-22 12:00",
                                 preferred_contact: "text", mobile_phone: "+17345550085", work_phone: "+17345554512")
      end
      let!(:child) do
        create(:user, :child, household: household1, first_name: "Billy", last_name: "South",
                              email: "e@f.com", joined_on: "2008/11/29", preferred_contact: "text",
                              birthdate: nil, mobile_phone: "+17345557737",
                              guardians: [adult1, adult2])
      end

      let!(:household2) { create(:household, name: "Blip", member_count: 0) }
      let!(:adult3) do
        create(:user, household: household2, first_name: "Zorgon", last_name: "Puzt",
                      email: "g@h.com", mobile_phone: "+17345558788", created_at: "2017-07-11 12:00")
      end

      context "as user" do
        let(:actor) { create(:user) }

        it "should return valid csv" do
          expect(exporter.to_csv).to eq(prepare_fixture("users/as_user.csv",
                                                        id: [child, adult2, adult1, adult3].map(&:id),
                                                        household_id: [household1, household2].map(&:id)))
        end
      end

      context "as admin, with inactive users" do
        let(:actor) { create(:admin) }
        let(:exporter) { described_class.new(User.by_name.where.not(id: actor.id), policy: policy) }

        it "should return valid csv" do
          expect(exporter.to_csv).to eq(prepare_fixture("users/as_admin.csv",
                                                        id: [child, adult2, adult1, adult3].map(&:id),
                                                        household_id: [household1, household2].map(&:id),
                                                        google_email: [adult2, adult1,
                                                                       adult3].map(&:google_email)))
        end
      end
    end
  end
end
