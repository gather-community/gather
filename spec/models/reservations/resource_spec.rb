# frozen_string_literal: true

require "rails_helper"

describe Reservations::Resource do
  describe "#all_guidelines" do
    let(:resource) { create(:resource, :with_guidelines) }
    let(:gl1) { resource.guidelines }
    let(:gl2) { resource.shared_guidelines[0].body }
    let(:gl3) { resource.shared_guidelines[1].body }

    it "combines shared and non-shared guidelines" do
      expect(resource.all_guidelines).to eq("#{gl1}\n\n---\n\n#{gl2}\n\n---\n\n#{gl3}")
    end
  end
end
