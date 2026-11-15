# frozen_string_literal: true

# == Schema Information
#
# Table name: people_memorials
#
#  id         :bigint           not null, primary key
#  birth_year :integer
#  cluster_id :bigint           not null
#  created_at :datetime         not null
#  death_year :integer          not null
#  obituary   :text
#  updated_at :datetime         not null
#  user_id    :bigint           not null
#
require "rails_helper"

describe People::Memorial do
  it "has valid factory" do
    create(:memorial)
  end

  describe "photo" do
    it "copies the user's photo" do
      user = create(:user, :with_photo)
      memorial = create(:memorial, user: user)
      expect(memorial.reload.photo).to be_attached
      expect(memorial.photo.blob).not_to eq(user.photo.blob)
    end

    # Active Storage only uploads a file once its transaction commits, so a user created in the same
    # transaction has no photo file to copy until then. Sample data generation does exactly this.
    it "copies the photo of a user created in the same transaction" do
      memorial = nil
      expect(Gather::ErrorReporter.instance).not_to receive(:report)
      ActiveRecord::Base.transaction do
        user = create(:user, :with_photo)
        memorial = create(:memorial, user: user)
      end
      expect(memorial.reload.photo).to be_attached
      expect(memorial.photo.download).to eq(memorial.user.photo.download)
    end
  end
end
