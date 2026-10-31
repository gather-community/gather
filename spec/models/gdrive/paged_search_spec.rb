# frozen_string_literal: true

require "rails_helper"

describe GDrive::PagedSearch do
  let(:searcher) { instance_double(GDrive::Searcher) }
  let(:cache) { ActiveSupport::Cache::MemoryStore.new }
  let(:batches) { {} }

  subject(:paged) do
    described_class.new(searcher: searcher, cache_key: "test", page_size: 10, expires_in: 15.minutes)
  end

  before do
    allow(Rails).to receive(:cache).and_return(cache)
    allow(searcher).to receive(:search) { |page_token:, page_size:| batches.fetch(page_token) }
  end

  def files(count, from: 1)
    Array.new(count) do |i|
      instance_double(Google::Apis::DriveV3::File, id: "f#{from + i}", name: "File #{from + i}",
        mime_type: "application/pdf", icon_link: "icon", web_view_link: "link", modified_time: nil)
    end
  end

  def names(page)
    page[:files].map(&:name)
  end

  context "with one batch that holds everything" do
    before { batches[nil] = {files: files(25), next_page_token: nil} }

    it "asks Google for a batch of 50 and pages through it 10 at a time" do
      first = paged.page(0)
      expect(searcher).to have_received(:search).with(page_token: nil, page_size: 50).once
      expect(names(first).first).to eq("File 1")
      expect(first[:files].size).to eq(10)
      expect(first).to include(found: 25, more: true)

      expect(paged.page(10)[:files].size).to eq(10)
      last = paged.page(20)
      expect(last[:files].size).to eq(5)
      expect(last[:more]).to be(false)
      expect(searcher).to have_received(:search).once
    end

    it "returns an empty last page if the results shrank while the cache was expired" do
      paged.page(0)
      cache.clear
      batches[nil] = {files: files(5), next_page_token: nil}
      expect(paged.page(10)).to include(files: [], found: 5, more: false)
    end
  end

  context "with several batches" do
    before do
      batches[nil] = {files: files(15), next_page_token: "t2"}
      batches["t2"] = {files: files(15, from: 16), next_page_token: nil}
    end

    it "serves from the cache while it has enough, and fetches more only when it runs short" do
      expect(paged.page(0)).to include(found: 15, more: true)
      expect(searcher).to have_received(:search).once

      expect(names(paged.page(10))).to eq((11..20).map { |i| "File #{i}" })
      expect(searcher).to have_received(:search).twice

      expect(paged.page(20)).to include(more: false)
      expect(searcher).to have_received(:search).twice
    end

    it "starts fresh for a first page" do
      paged.page(0)
      paged.page(0)
      expect(searcher).to have_received(:search).with(page_token: nil, page_size: 50).twice
    end

    it "refetches from the start when the cache has expired" do
      paged.page(0)
      cache.clear
      expect(names(paged.page(10)).first).to eq("File 11")
    end
  end

  context "when batches come back with nothing from the linked drives" do
    before do
      (0..9).each { |i| batches[i.zero? ? nil : "t#{i}"] = {files: [], next_page_token: "t#{i + 1}"} }
    end

    it "keeps asking, but no more than #{described_class::MAX_REQUESTS} times per page" do
      page = paged.page(0)
      expect(searcher).to have_received(:search).exactly(described_class::MAX_REQUESTS).times
      expect(page).to include(files: [], more: true)
    end
  end
end
