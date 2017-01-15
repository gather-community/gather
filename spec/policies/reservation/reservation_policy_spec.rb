require 'rails_helper'

describe Reservation::ReservationPolicy do
  include_context "policy objs"
  let(:resource) { create(:resource, community: community) }
  let(:reservation) { build(:reservation, reserver: user, resource: resource) }

  describe "permissions" do
    shared_examples_for "allow all active users" do
      it "grants access to active users" do
        expect(subject).to permit(user, reservation)
      end

      it "denies access to inactive users" do
        expect(subject).not_to permit(inactive_user, reservation)
      end
    end

    shared_examples_for "allow reserver and admins" do
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

    permissions :choose_reserver? do
      it "allows admins only" do
        expect(subject).not_to permit(user, reservation)
        expect(subject).to permit(admin, reservation)
      end
    end

    context "non-meal reservation" do
      permissions :index?, :show?, :new?, :create? do
        it_behaves_like "allow all active users"
      end

      permissions :edit?, :update? do
        it_behaves_like "allow reserver and admins"
      end

      permissions :destroy? do
        context "future reservation" do
          let(:reservation) do
            build(:reservation, reserver: user, starts_at: 1.day.from_now, resource: resource)
          end
          it_behaves_like "allow reserver and admins"
        end

        context "just created reservation" do
          let(:reservation) do
            build(:reservation, reserver: user, resource: resource,
              starts_at: 1.day.ago, created_at: 50.minutes.ago)
          end
          it_behaves_like "allow reserver and admins"
        end

        context "old past reservation" do
          let(:reservation) do
            build(:reservation, reserver: user, resource: resource,
              starts_at: 1.day.ago, created_at: 1.week.ago)
          end

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

    context "meal reservation" do
      let(:reservation) { build(:reservation, reserver: user, resource: resource, kind: "_meal") }

      permissions :index?, :show? do
        it_behaves_like "allow all active users"
      end

      permissions :new?, :create?, :edit?, :update?, :destroy? do
        it "denies access to all" do
          expect(subject).not_to permit(user, reservation)
          expect(subject).not_to permit(other_user, reservation)
          expect(subject).not_to permit(admin, reservation)
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
    subject { Reservation::ReservationPolicy.new(user, reservation).permitted_attributes }

    shared_examples_for "basic attribs" do
      it "should allow basic attribs" do
        expect(subject).to contain_exactly(*%i(name kind sponsor_id starts_at ends_at guidelines_ok note))
      end
    end

    context "regular user" do
      it_behaves_like "basic attribs"
    end

    context "admin" do
      let(:user) { admin }

      it "should allow admin-only attribs" do
        expect(subject).to contain_exactly(*%i(name kind reserver_id
          sponsor_id starts_at ends_at guidelines_ok note))
      end
    end

    context "outside admin" do
      let(:user) { admin_in_cluster }
      it_behaves_like "basic attribs"
    end
  end
end
