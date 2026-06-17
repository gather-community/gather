# frozen_string_literal: true

require "rails_helper"

describe GDrive::Searcher do
  let(:parser) { Search::QueryParser.new("solar panels") }
  let(:reader_email) { "jane@example.com" }
  let(:drive_ids) { %w[drive_abc drive_xyz] }
  let(:wrapper) { instance_double(GDrive::Wrapper) }

  subject(:searcher) do
    described_class.new(wrapper: wrapper, reader_email: reader_email, drive_ids: drive_ids, parser: parser)
  end

  def make_file(id:, name:)
    instance_double(Google::Apis::DriveV3::File, id: id, name: name,
                                                 web_view_link: "https://drive.google.com/file/#{id}")
  end

  describe "#search" do
    context "with blank parser" do
      let(:parser) { Search::QueryParser.new("") }

      it "returns empty result without calling the API" do
        expect(wrapper).not_to receive(:list_files)
        result = searcher.search
        expect(result).to eq({files: [], next_page_token: nil})
      end
    end

    context "with no drive_ids" do
      let(:drive_ids) { [] }

      it "returns empty result without calling the API" do
        expect(wrapper).not_to receive(:list_files)
        result = searcher.search
        expect(result).to eq({files: [], next_page_token: nil})
      end
    end

    context "happy path" do
      let(:file1) { make_file(id: "f1", name: "Solar Report") }
      let(:api_result) do
        instance_double(Google::Apis::DriveV3::FileList, files: [file1], next_page_token: nil)
      end

      before { allow(wrapper).to receive(:list_files).and_return(api_result) }

      it "includes fullText terms, reader filter, and parents filter in query" do
        expect(wrapper).to receive(:list_files).with(hash_including(
          q: a_string_including("fullText contains 'solar'")
            .and(include("'jane@example.com' in readers"))
            .and(include("'drive_abc' in parents"))
            .and(include("'drive_xyz' in parents"))
        ))
        searcher.search
      end

      it "returns all files the API returns" do
        expect(searcher.search[:files]).to eq([file1])
      end

      it "passes next_page_token through" do
        expect(searcher.search[:next_page_token]).to be_nil
      end
    end

    context "with pagination" do
      let(:api_result) do
        instance_double(Google::Apis::DriveV3::FileList, files: [], next_page_token: "token_abc")
      end

      before { allow(wrapper).to receive(:list_files).and_return(api_result) }

      it "returns next_page_token when present" do
        expect(searcher.search[:next_page_token]).to eq("token_abc")
      end

      it "passes page_token to the API call" do
        expect(wrapper).to receive(:list_files).with(hash_including(page_token: "prev_token"))
        searcher.search(page_token: "prev_token")
      end
    end
  end
end
