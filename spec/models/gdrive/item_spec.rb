# frozen_string_literal: true

require "rails_helper"

describe GDrive::Item do
  it "has a valid factory" do
    create(:gdrive_item)
  end
end
