# frozen_string_literal: true

require "rails_helper"

describe GDrive::Searcher do
  let(:parser) { Search::QueryParser.new("solar panels") }
  let(:accessible_drive_ids) { %w[drive_aaa drive_bbb] }
  let(:wrapper) { instance_double(GDrive::Wrapper) }

  subject(:searcher) do
    described_class.new(wrapper: wrapper, accessible_drive_ids: accessible_drive_ids, parser: parser)
  end

  def make_file(id:, name:, drive_id:)
    instance_double(Google::Apis::DriveV3::File, id: id, name: name, drive_id: drive_id,
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

    context "happy path" do
      let(:file_in_drive) { make_file(id: "f1", name: "Solar Report", drive_id: "drive_aaa") }
      let(:file_not_in_drive) { make_file(id: "f2", name: "Other File", drive_id: "drive_zzz") }
      let(:api_result) do
        instance_double(Google::Apis::DriveV3::FileList,
                        files: [file_in_drive, file_not_in_drive],
                        next_page_token: nil)
      end

      before do
        allow(wrapper).to receive(:list_files).and_return(api_result)
      end

      it "calls the API with the correct query" do
        expect(wrapper).to receive(:list_files).with(
          hash_including(q: a_string_including("fullText contains 'solar'"))
        )
        searcher.search
      end

      it "filters out files not in accessible drives" do
        result = searcher.search
        expect(result[:files]).to eq([file_in_drive])
      end

      it "passes next_page_token through" do
        expect(searcher.search[:next_page_token]).to be_nil
      end
    end

    context "with pagination" do
      let(:api_result) do
        instance_double(Google::Apis::DriveV3::FileList,
                        files: [],
                        next_page_token: "token_abc")
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
