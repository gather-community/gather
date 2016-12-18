require 'rails_helper'

describe Household do
  describe "emergency_contacts" do
    let(:household) { create(:household, emergency_contacts: [
      {
        name: "Lozer Whips",
        relationship: "Pinn's Dad",
        city: "Jonkler, KY",
        phones: [
          {
            number: "+16548768903",
            type: "mobile"
          },{
            number: "+16467446452",
            type: "home"
          }
        ]
      },{
        name: "Jep Numbles",
        relationship: "Burl's interlocutor",
        city: "Olo Ponto Nuevo, PR",
        phones: [
          {
            number: "+14426242232",
            type: "mobile"
          }
        ]
      }
    ]) }

    before { household.reload }

    it "should allow retrieval" do
      expect(household.emergency_contacts[0]["phones"][0]["type"]).to eq "mobile"
    end
  end
end
