# frozen_string_literal: true

require "rails_helper"

describe GDrive::Config do
  it "has valid factory" do
    create(:gdrive_config)
  end
end
