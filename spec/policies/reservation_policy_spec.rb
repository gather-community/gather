require 'rails_helper'

describe Reservation::ReservationPolicy do
  describe "permissions" do
    include_context "policy objs"

    permissions :index?, :show?, :new?, :create? do
      it "grants access to active users" do
        expect(subject).to permit(user, Reservation::Reservation)
      end

      it "denies access to inactive users" do
        expect(subject).not_to permit(inactive_user, Reservation::Reservation)
      end
    end

    shared_examples_for "modify" do
      it "grants access to reserver" do
        expect(subject).to permit(user, reservation)
      end

      it "grants access to admins" do
        expect(subject).to permit(admin, reservation)
      end

      it "denies access to other regular users" do
        expect(subject).not_to permit(other_user, reservation)
      end
    end

    permissions :edit?, :update? do
      let(:reservation) { Reservation::Reservation.new(reserver: user) }

      it_behaves_like "modify"
    end

    permissions :destroy? do
      context "future reservation" do
        let(:reservation) { Reservation::Reservation.new(reserver: user, starts_at: 1.day.from_now) }
        it_behaves_like "modify"
      end

      context "just created reservation" do
        let(:reservation) { Reservation::Reservation.new(reserver: user, starts_at: 1.day.ago,
          created_at: 50.minutes.ago) }
        it_behaves_like "modify"
      end

      context "old past reservation" do
        let(:reservation) { Reservation::Reservation.new(reserver: user, starts_at: 1.day.ago,
          created_at: 1.week.ago) }

        it "denies access to non-admins" do
          expect(subject).not_to permit(user, reservation)
          expect(subject).not_to permit(other_user, reservation)
        end

        it "grants access to admins" do
          expect(subject).to permit(admin, reservation)
        end
      end
    end

  end

  describe "scope" do
    let!(:reservation1) { create(:reservation) }
    let!(:reservation2) { create(:reservation) }
    let(:user) { User.new }

    it "returns all reservations" do
      permitted = Reservation::ReservationPolicy::Scope.new(user, Reservation::Reservation.all).resolve
      expect(permitted).to contain_exactly(reservation1, reservation2)
    end
  end

  describe "permitted_attributes" do
    let(:user) { User.new }
    let(:reservation) { Reservation::Reservation.new(reserver: user) }
    subject { Reservation::ReservationPolicy.new(user, reservation).permitted_attributes }

    it "should allow appropriate attribs" do
      expect(subject).to contain_exactly(*%i(name kind reserver_id resource_id
        sponsor_id starts_at ends_at guidelines_ok))
    end
  end
end
