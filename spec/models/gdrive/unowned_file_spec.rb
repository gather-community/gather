# frozen_string_literal: true

require "rails_helper"

describe GDrive::UnownedFile do
  it "has a valid factory" do
    create(:gdrive_unowned_file)
  end
end
