# frozen_string_literal: true

require "rails_helper"

describe FormHelper do
  describe "#error_summary" do
    # A stand-in for a form object, with errors added directly.
    let(:record_class) do
      Class.new do
        include ActiveModel::Model

        attr_accessor :name, :email

        def self.model_name
          ActiveModel::Name.new(self, nil, "Thing")
        end
      end
    end
    let(:record) { record_class.new }

    def summary(**options)
      html = helper.error_summary(record, **options)
      html && Capybara.string(html)
    end

    it "is nil without errors" do
      expect(summary).to be_nil
    end

    it "says how many fields have errors, as a single line" do
      record.errors.add(:name, :blank)
      record.errors.add(:email, :blank)
      expect(summary).to have_css("div.alert.alert-danger", text: "There are 2 errors on the form below.")
      expect(summary).to have_no_css("li")
    end

    it "uses the singular for one" do
      record.errors.add(:name, :blank)
      expect(summary).to have_text("There is 1 error on the form below.")
    end

    it "shows a lone base error as a single line" do
      record.errors.add(:base, "That time is taken.")
      expect(summary).to have_css("div.alert-danger", text: "That time is taken.")
      expect(summary).to have_no_css("li")
      expect(summary).to have_no_text("on the form below")
    end

    it "lists base errors and the count of field errors when there's more than one line" do
      record.errors.add(:base, "That time is taken.")
      record.errors.add(:base, "The room is closed.")
      record.errors.add(:name, :blank)
      expect(summary.all("li").map(&:text))
        .to eq(["That time is taken.", "The room is closed.", "There is 1 error on the form below."])
    end

    it "leaves out the count when the form doesn't want it" do
      record.errors.add(:base, "That time is taken.")
      record.errors.add(:name, :blank)
      expect(summary(count_fields: false)).to have_css("div.alert-danger", text: "That time is taken.")
      expect(summary(count_fields: false)).to have_no_text("on the form below")
    end
  end
end
