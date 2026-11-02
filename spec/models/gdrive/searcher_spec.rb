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

  def make_file(id:, name:, drive_id: "drive_abc")
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

      it "searches all drives with the fullText terms and reader filter" do
        expect(wrapper).to receive(:list_files).with(hash_including(
          corpora: "allDrives",
          q: a_string_including("fullText contains 'solar'")
            .and(include("'jane@example.com' in readers"))
            .and(satisfy { |q| q.exclude?("in parents") })
        ))
        searcher.search
      end

      it "returns the files the API returns from the community's drives" do
        expect(searcher.search[:files]).to eq([file1])
      end

      context "when some files are in other drives or no shared drive" do
        let(:in_subfolder) { make_file(id: "f2", name: "Solar Notes", drive_id: "drive_xyz") }
        let(:other_drive) { make_file(id: "f3", name: "Solar Elsewhere", drive_id: "drive_other") }
        let(:my_drive) { make_file(id: "f4", name: "Solar Personal", drive_id: nil) }
        let(:api_result) do
          instance_double(Google::Apis::DriveV3::FileList,
            files: [file1, in_subfolder, other_drive, my_drive], next_page_token: nil)
        end

        it "keeps only files in the community's linked drives" do
          expect(searcher.search[:files]).to eq([file1, in_subfolder])
        end
      end

      it "passes next_page_token through" do
        expect(searcher.search[:next_page_token]).to be_nil
      end
    end

    context "with file types" do
      let(:api_result) { instance_double(Google::Apis::DriveV3::FileList, files: [], next_page_token: nil) }

      before { allow(wrapper).to receive(:list_files).and_return(api_result) }

      it "adds no type filter when all types are allowed" do
        searcher.search
        expect(wrapper).to have_received(:list_files).with(hash_including(q: satisfy { |q|
          q.exclude?("mimeType")
        }))
      end

      context "when limited to some types, including other files" do
        subject(:searcher) do
          described_class.new(wrapper: wrapper, reader_email: reader_email, drive_ids: drive_ids,
            parser: parser, file_types: %w[doc other])
        end

        it "matches those types, and anything that isn't one of the named types" do
          searcher.search
          expect(wrapper).to have_received(:list_files).with(hash_including(q: a_string_including(
            "(mimeType = 'application/vnd.google-apps.document' or " \
            "(mimeType != 'application/vnd.google-apps.document' and " \
            "mimeType != 'application/vnd.google-apps.spreadsheet'"
          )))
        end
      end

      context "with no types" do
        subject(:searcher) do
          described_class.new(wrapper: wrapper, reader_email: reader_email, drive_ids: drive_ids,
            parser: parser, file_types: [])
        end

        it "returns nothing without calling the API" do
          expect(searcher.search[:files]).to eq([])
          expect(wrapper).not_to have_received(:list_files)
        end
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
