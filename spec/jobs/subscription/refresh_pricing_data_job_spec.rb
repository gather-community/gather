# frozen_string_literal: true

require "rails_helper"

describe Subscription::RefreshPricingDataJob do
  let(:fetcher) { instance_double(Subscription::PricingDataFetcher) }

  before { allow(Subscription::PricingDataFetcher).to receive(:new).and_return(fetcher) }

  it "refreshes base + latest CPI and every non-USD currency" do
    allow(fetcher).to receive(:fetch_inflation!)
    allow(fetcher).to receive(:fetch_latest_inflation!)
    allow(fetcher).to receive(:fetch_exchange_rate!)

    described_class.new.perform

    expect(fetcher).to have_received(:fetch_inflation!).with(Subscription::PriceCalculator::BASE_YEAR)
    expect(fetcher).to have_received(:fetch_latest_inflation!)
    expect(fetcher).to have_received(:fetch_exchange_rate!).with("eur")
    expect(fetcher).not_to have_received(:fetch_exchange_rate!).with("usd")
  end

  it "reports a single item's failure to Sentry and keeps going" do
    allow(fetcher).to receive(:fetch_inflation!)
      .and_raise(Subscription::PricingDataFetcher::FetchError, "cpi down")
    allow(fetcher).to receive(:fetch_latest_inflation!)
    allow(fetcher).to receive(:fetch_exchange_rate!)
    expect(Gather::ErrorReporter.instance).to receive(:report).at_least(:once)

    expect { described_class.new.perform }.not_to raise_error
    # The currencies were still processed despite the CPI failure.
    expect(fetcher).to have_received(:fetch_exchange_rate!).with("cad")
  end
end
