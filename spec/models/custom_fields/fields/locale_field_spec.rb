# frozen_string_literal: true

require "rails_helper"

describe CustomFields::Fields::LocaleField do
  let(:field) { described_class.new(key: :locale, required: true, default: "en") }

  it "offers every available locale, named in its own language" do
    expect(field.collection).to match_array(I18n.available_locales.map(&:to_s))
    expect(field.option_label("de")).to eq("Deutsch")
    expect(field.option_label("fr-CA")).to eq("Français (Canada)")
  end

  it "only accepts available locales" do
    expect(field.validation[:inclusion][:in]).to match_array(I18n.available_locales.map(&:to_s))
  end

  it "labels the options in the settings form with the language names" do
    community = create(:community)
    entry = community.settings.entries.find { |e| e.key == :locale }
    expect(entry.input_params[:collection]).to include(["de", "Deutsch"], ["en", "English"])
  end
end
