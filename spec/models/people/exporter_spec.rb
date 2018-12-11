# frozen_string_literal: true

require "rails_helper"

describe People::Exporter do
  let(:actor) { create(:user) }
  let(:policy) { UserPolicy.new(actor, User.new(household: Household.new(community: actor.community))) }
  let(:exporter) { described_class.new(User.by_name.where.not(id: actor.id), policy: policy) }

  describe "to_csv" do
    context "with no users" do
      it "should return valid csv" do
        expect(exporter.to_csv).to eq("ID,First Name,Last Name,Unit Num,Unit Suffix,Birthdate,Email,"\
          "Is Child,Mobile Phone,Home Phone,Work Phone,Join Date,Preferred Contact,Garage Nums,Vehicles\n")
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
      let!(:household) do
        create(:household, with_members: false, unit_num: "20", unit_suffix: "3A", garage_nums: "4,9")
      end
      let!(:vehicle1) do
        create(:vehicle, household: household, color: "Blue", make: "Ford",
                         model: "F-150", plate: "XYZ123")
      end
      let!(:vehicle2) do
        create(:vehicle, household: household, color: "Red", make: "GMC",
                         model: "Jimmy", plate: "XYZ456")
      end
      let!(:adult1) do
        create(:user, household: household, first_name: "Ron", last_name: "South", email: "a@b.com",
                      birthdate: "1980/07/20", joined_on: "2016/03/12", preferred_contact: "email",
                      mobile_phone: "+17345556376", home_phone: "+17345551981")
      end
      let!(:adult2) do
        create(:user, household: household, first_name: "Jenn", last_name: "Blount", email: "d@d.com",
                      birthdate: "0004/03/10", joined_on: "2016/08/01", preferred_contact: "text",
                      mobile_phone: "+17345550085", work_phone: "+17345554512")
      end
      let!(:child) do
        create(:user, :child, household: household, first_name: "Billy", last_name: "South", email: "e@f.com",
                              birthdate: nil, joined_on: "2008/11/29", preferred_contact: "text",
                              mobile_phone: "+17345557737", guardians: [adult1, adult2])
      end

      it "should return valid csv" do
        expect(exporter.to_csv).to eq(prepare_expectation("users.csv", id: [child, adult2, adult1].map(&:id)))
      end
    end
  end
end
