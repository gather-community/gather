# frozen_string_literal: true

require "rails_helper"

describe Reservations::ReservationPolicy do
  include_context "policy objs"
  let(:starts_at) { Time.current + 1.week }
  let(:ends_at) { starts_at + 1.hour }
  let(:created_at) { nil }
  let(:reserver) { create(:user) }
  let(:resource) { create(:resource, community: community) }
  let(:reservation) do
    build(:reservation, reserver: reserver, resource: resource, created_at: created_at,
                        starts_at: starts_at, ends_at: ends_at)
  end
  let(:record) { reservation }

  describe "permissions" do
    shared_examples_for "permits admins and reserver" do
      it_behaves_like "permits admins but not regular users"
      it "permits reserver" do
        expect(subject).to permit(reserver, reservation)
      end
    end

    shared_examples_for "permits admins but not reserver" do
      it_behaves_like "permits admins but not regular users"
      it "forbids reserver" do
        expect(subject).not_to permit(reserver, reservation)
      end
    end

    permissions :choose_reserver? do
      it_behaves_like "permits admins but not reserver"
    end

    context "non-meal reservation" do
      permissions :index?, :show?, :new?, :create? do
        it_behaves_like "permits active users only"
      end

      permissions :edit?, :update? do
        it_behaves_like "permits admins and reserver"

        context "with reservation in past" do
          let(:starts_at) { 1.week.ago }
          it_behaves_like "permits admins but not reserver"
        end
      end

      permissions :destroy? do
        context "future reservation" do
          let(:starts_at) { 1.day.from_now }
          it_behaves_like "permits admins and reserver"
        end

        context "just-created reservation" do
          let(:starts_at) { 1.day.ago }
          let(:created_at) { 50.minutes.ago }
          it_behaves_like "permits admins and reserver"
        end

        context "old past reservation" do
          let(:starts_at) { 1.day.ago }
          let(:created_at) { 1.week.ago }
          it_behaves_like "permits admins but not reserver"
        end
      end
    end

    context "meal reservation" do
      let(:reservation) { build(:reservation, reserver: reserver, resource: resource, kind: "_meal") }

      permissions :index?, :show? do
        it_behaves_like "permits active users only"
      end

      permissions :new?, :create?, :destroy? do
        it "forbids all" do
          expect(subject).not_to permit(reserver, reservation)
          expect(subject).not_to permit(user, reservation)
          expect(subject).not_to permit(admin, reservation)
        end
      end

      permissions :edit?, :update? do
        it "permits access to admins, meals coordinators, and meal creator, and forbids others" do
          expect(subject).to permit(reserver, reservation)
          expect(subject).to permit(admin, reservation)
          expect(subject).to permit(meals_coordinator, reservation)
          expect(subject).not_to permit(user, reservation)
        end
      end
    end
  end

  describe "scope" do
    let!(:reservation1) { create(:reservation) }
    let!(:reservation2) { create(:reservation) }
    let(:reserver) { User.new }

    it "returns all reservations" do
      permitted = Reservations::ReservationPolicy::Scope.new(reserver, Reservations::Reservation.all).resolve
      expect(permitted).to contain_exactly(reservation1, reservation2)
    end
  end

  describe "permitted_attributes" do
    let(:admin_attribs) { basic_attribs + %i[reserver_id] }
    subject { Reservations::ReservationPolicy.new(reserver, reservation).permitted_attributes }

    shared_examples_for "basic attribs" do
      it "should allow basic attribs" do
        expect(subject).to contain_exactly(*basic_attribs)
      end
    end

    shared_examples_for "each user type" do
      context "regular user" do
        it_behaves_like "basic attribs"
      end

      context "admin" do
        let(:reserver) { admin }

        it "should allow admin-only attribs" do
          expect(subject).to contain_exactly(*admin_attribs)
        end
      end

      context "outside admin" do
        let(:reserver) { admin_in_cmtyB }
        it_behaves_like "basic attribs"
      end
    end

    context "regular reservation" do
      let(:basic_attribs) { %i[name kind sponsor_id starts_at ends_at guidelines_ok note] }
      it_behaves_like "each user type"
    end

    context "meal reservation" do
      let(:basic_attribs) { %i[starts_at ends_at note] }
      let(:reservation) { build(:reservation, reserver: reserver, resource: resource, kind: "_meal") }
      it_behaves_like "each user type"
    end
  end
end
