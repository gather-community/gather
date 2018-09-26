# coding: utf-8
require "rails_helper"

describe People::Exporter do
  let(:exporter) { described_class.new(User.by_name) }

  describe "to_csv" do
    context "with no users" do
      it "should return valid csv" do
        expect(exporter.to_csv).to eq("ID,First Name,Last Name,Unit Num and Suffix,Birthdate,Email,Is Child,"\
          "Mobile Phone,Home Phone,Work Phone,Join Date,Preferred Contact,Garage Nums,Vehicles\n")
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
      let!(:household) { create(:household, with_members: false, unit_num: "20", unit_suffix: "3A", garage_nums: "4,9") }
      let!(:vehicle1) { create(:vehicle, household: household, color: "Blue", make: "Ford",
        model: "F-150", plate: "XYZ123") }
      let!(:vehicle2) { create(:vehicle, household: household, color: "Red", make: "GMC",
        model: "Jimmy", plate: "XYZ456") }
      let!(:adult1) { create(:user, household: household, first_name: "Ron", last_name: "South",
        email: "a@b.com", birthdate: "1980/07/20", joined_on: "2016/03/12", preferred_contact: "email",
        mobile_phone: "+17345556376", home_phone: "+17345551981") }
      let!(:adult2) { create(:user, household: household, first_name: "Jenn", last_name: "Blount",
        email: "d@d.com", birthdate: "0004/03/10", joined_on: "2016/08/01", preferred_contact: "text",
        mobile_phone: "+17345550085", work_phone: "+17345554512") }
      let!(:child) { create(:user, :child, household: household, first_name: "Billy", last_name: "South",
        email: "e@f.com", birthdate: nil, joined_on: "2008/11/29", preferred_contact: "text",
        mobile_phone: "+17345557737", guardians: [adult1, adult2]) }

      it "should return valid csv" do
        expect(exporter.to_csv).to eq prepare_expectation("users.csv", id: [child, adult2, adult1].map(&:id))
      end
    end
  end
end
