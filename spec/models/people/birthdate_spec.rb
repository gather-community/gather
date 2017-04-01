require "rails_helper"

describe People::Birthdate do
  describe "age and birthdate" do
    shared_examples_for "nil" do
      it "has nil age and birthdate" do
        expect(user.birthdate_str).to be_nil
        expect(user.birthdate).to be_nil
        expect(user.age).to be_nil
      end
    end

    shared_examples_for "error" do
      it "has error" do
        expect(user).to be_invalid
        expect(user.errors[:birthdate_str].join).to match /invalid/
        expect(user.birthdate).to be_nil
        expect(user.birthdate_str).not_to be_blank
        user.birthdate_str = "Feb 5 2001"
        expect(user).to be_valid
      end
    end

    shared_examples_for "no year" do |day|
      before { user.reload }

      it "retrieves properly" do
        expect(user.birthdate.year).to eq 4
        expect(user.birthdate.month).to eq 2
        expect(user.birthdate.day).to eq day
        expect(user.birthdate).to eq Date.new(4, 2, day)
        str = "Feb #{day.to_s.rjust(2, '0')}"
        expect(user.birthdate_str).to eq str
        expect(user.reload.birthdate_str).to eq str
      end

      it "has nil age" do
        expect(user.age).to eq nil
      end
    end

    context "with no birthdate" do
      let(:user) { create(:user, birthdate_str: nil) }
      it_behaves_like "nil"
    end

    context "with blank birthdate" do
      let(:user) { build(:user, birthdate_str: "") }
      it_behaves_like "nil"
    end

    context "with no year" do
      let(:user) { create(:user, birthdate_str: "Feb 2") }
      it_behaves_like "no year", 2
    end

    context "with no year on leap day" do
      let(:user) { create(:user, birthdate_str: "Feb 29") }
      it_behaves_like "no year", 29
    end

    context "with two digit year" do
      let(:user) { build(:user, birthdate_str: "Feb 18 80") }
      it_behaves_like "error"
    end

    context "with nonsense day" do
      let(:user) { build(:user, birthdate_str: "Feb 45 1981") }
      it_behaves_like "error"
    end

    context "with full birthdate" do
      let(:user) { create(:user, birthdate_str: "2000-6-15") }

      it "gets set properly" do
        expect(user.birthdate_str).to eq "Jun 15 2000"
        expect(user.birthdate).to eq Date.new(2000, 6, 15)
        expect(user.reload.birthdate_str).to eq "Jun 15 2000"
      end

      it "can be set to nil" do
        user.birthdate_str = nil
        expect(user).to be_valid
      end

      it "has correct age when today is before bday" do
        Timecop.freeze("2016-2-1") do
          expect(user.age).to eq 15
        end
      end

      it "has correct age when today is after bday" do
        Timecop.freeze("2016-9-1") do
          expect(user.age).to eq 16
        end
      end
    end
  end
end
