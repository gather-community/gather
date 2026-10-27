# frozen_string_literal: true

require "rails_helper"

describe Gather::Collation do
  let(:names) { %w[Zoe Émile Åsa Ärla Adam Ödön Oscar zack] }

  def sort_in(locale, strings)
    I18n.with_locale(locale) { described_class.sort(strings) }
  end

  it "has a collation in the database for every locale" do
    names = I18n.available_locales.map { |locale| Gather::Locales.collation(locale) }
    existing = ActiveRecord::Base.connection.select_values(
      ActiveRecord::Base.sanitize_sql_array(["SELECT collname FROM pg_collation WHERE collname IN (?)", names])
    )
    expect(existing).to match_array(names)
  end

  it "sorts accented letters with their base letters in English, not after z" do
    expect(sort_in(:en, names)).to eq(%w[Adam Ärla Åsa Émile Ödön Oscar zack Zoe])
  end

  it "follows each language's rules" do
    expect(sort_in(:de, names)).to eq(%w[Adam Ärla Åsa Émile Ödön Oscar zack Zoe])
    expect(sort_in(:sv, names)).to eq(%w[Adam Émile Oscar zack Zoe Åsa Ärla Ödön])
  end

  it "sorts objects by a key, keeping the order of equal keys" do
    items = [%w[Zoe 1], %w[Åsa 2], %w[Zoe 3], %w[Adam 4]]
    sorted = I18n.with_locale(:en) { described_class.sort_by(items, &:first) }
    expect(sorted.map(&:last)).to eq(%w[4 2 1 3])
  end

  it "handles short lists without a query" do
    expect(ActiveRecord::Base.connection).not_to receive(:select_values)
    expect(described_class.sort([])).to eq([])
    expect(described_class.sort(["Åsa"])).to eq(["Åsa"])
  end

  describe "ApplicationRecord.alpha_order" do
    before do
      %w[Zoo Ängel Abc].each { |name| create(:group, name: name) }
    end

    it "sorts by the current locale's rules" do
      expect(I18n.with_locale(:en) { Groups::Group.alpha_order(:name).pluck(:name) }).to eq(%w[Abc Ängel Zoo])
      expect(I18n.with_locale(:sv) { Groups::Group.alpha_order(:name).pluck(:name) }).to eq(%w[Abc Zoo Ängel])
      expect(I18n.with_locale(:en) { Groups::Group.alpha_order("groups.name": :desc).pluck(:name) })
        .to eq(%w[Zoo Ängel Abc])
    end
  end
end
