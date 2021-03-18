# frozen_string_literal: true

require "rails_helper"

describe Calendars::Calendar do
  describe "#all_guidelines" do
    let(:calendar) { create(:calendar, :with_shared_guidelines) }
    let(:gl1) { calendar.guidelines }
    let(:gl2) { calendar.shared_guidelines[0].body }
    let(:gl3) { calendar.shared_guidelines[1].body }

    it "combines shared and non-shared guidelines" do
      expect(calendar.all_guidelines).to eq("#{gl1}\n\n---\n\n#{gl2}\n\n---\n\n#{gl3}")
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
    let!(:calendar) { create(:calendar) }

    context "with events" do
      let!(:event) { create(:event, calendar: calendar) }

      it "destroys events" do
        calendar.destroy
        expect(Calendars::Event.count).to be_zero
      end
    end

    context "with protocols" do
      let!(:protocol) { create(:calendar_protocol, calendars: [calendar]) }

      it "does not destroy protocols" do
        calendar.destroy
        expect { protocol.reload }.not_to raise_error
      end
    end

    context "with shared guidelines" do
      let!(:calendar) { create(:calendar, :with_shared_guidelines) }

      it "does not destroy guidelines" do
        calendar.destroy
        expect { calendar.shared_guidelines[0].reload }.not_to raise_error
      end
    end
  end
end
