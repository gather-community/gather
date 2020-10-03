# frozen_string_literal: true

require "rails_helper"

describe Reservations::Resource do
  describe "#all_guidelines" do
    let(:resource) { create(:resource, :with_shared_guidelines) }
    let(:gl1) { resource.guidelines }
    let(:gl2) { resource.shared_guidelines[0].body }
    let(:gl3) { resource.shared_guidelines[1].body }

    it "combines shared and non-shared guidelines" do
      expect(resource.all_guidelines).to eq("#{gl1}\n\n---\n\n#{gl2}\n\n---\n\n#{gl3}")
    end
  end

  # Our approach to destruction is to:
  # - Set the policy to only disallow deletions based on what users of various roles should be able
  #   to destroy given various combinations of existing associations.
  # - Set association `dependent` options to avoid DB constraint errors UNLESS the destroy is never allowed.
  # - In the model spec, assume destroy has been called and test for the appropriate behavior
  #   (dependent destruction, nullification, or error) for each foreign key.
  # - In the policy spec, test for the appropriate restrictions on destroy.
  # - In the feature spec, test the destruction/deactivation/activation happy paths.
  describe "destruction" do
    let!(:resource) { create(:resource) }

    context "with reservations" do
      let!(:reservation) { create(:reservation, resource: resource) }

      it "destroys reservations" do
        resource.destroy
        expect(Reservations::Reservation.count).to be_zero
      end
    end

    context "with protocols" do
      let!(:protocol) { create(:reservation_protocol, resources: [resource]) }

      it "does not destroy protocols" do
        resource.destroy
        expect { protocol.reload }.not_to raise_error
      end
    end

    context "with shared guidelines" do
      let!(:resource) { create(:resource, :with_shared_guidelines) }

      it "does not destroy guidelines" do
        resource.destroy
        expect { resource.shared_guidelines[0].reload }.not_to raise_error
      end
    end
  end
end
