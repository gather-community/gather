# frozen_string_literal: true

require "rails_helper"

describe GDrive::SharedDrive do
  it "has a valid factory" do
    create(:gdrive_shared_drive)
  end
end
