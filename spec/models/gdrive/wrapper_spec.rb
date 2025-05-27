# frozen_string_literal: true

require "rails_helper"

describe GDrive::Wrapper do
  let!(:config) { create(:gdrive_config, org_user_id: "drive.admin@gocoho.net") }
  let!(:wrapper) { GDrive::Wrapper.new(config: config, google_user_id: config.org_user_id) }

  describe "error handling" do
    context "server error" do
      before do
        service = double
        allow(service).to receive(:get_file).and_raise(Google::Apis::ServerError.new("oops"))
        allow(wrapper).to receive(:service).and_return(service)
      end

      it "raises ServerError unchanged" do
        expect { wrapper.get_file }.to raise_error(Google::Apis::ServerError, "oops")
      end
    end

    context "rate limit error" do
      before do
        service = double
        allow(service).to receive(:get_file).and_raise(Google::Apis::ClientError.new("too many requests"))
        allow(wrapper).to receive(:service).and_return(service)
      end

      it "raises custom error" do
        expect { wrapper.get_file }.to raise_error(GDrive::Wrapper::RateLimitError, "too many requests")
      end
    end

    context "other client error" do
      before do
        service = double
        allow(service).to receive(:get_file).and_raise(Google::Apis::ClientError.new("oops"))
        allow(wrapper).to receive(:service).and_return(service)
      end

      it "raises client error" do
        expect { wrapper.get_file }.to raise_error(Google::Apis::ClientError, "oops")
      end
    end
  end
end
