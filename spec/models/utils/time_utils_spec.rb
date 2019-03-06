require "rails_helper"

describe Utils::TimeUtils do
  describe "humanize_interval" do
    it "works for < 1 minute" do
      expect(Utils::TimeUtils.humanize_interval(59)).to eq "under 1 minute"
    end

    it "works for 1 minute" do
      expect(Utils::TimeUtils.humanize_interval(60)).to eq "1 minute"
    end

    it "works for 2 minutes" do
      expect(Utils::TimeUtils.humanize_interval(120)).to eq "2 minutes"
    end

    it "works for 2 minutes plus a bit" do
      expect(Utils::TimeUtils.humanize_interval(122)).to eq "2 minutes"
    end

    it "works for 3 minutes minus a bit" do
      expect(Utils::TimeUtils.humanize_interval(179)).to eq "2 minutes"
    end

    it "works for 1 hour" do
      expect(Utils::TimeUtils.humanize_interval(3600)).to eq "1 hour"
    end

    it "works for 1 hour 20 minutes" do
      expect(Utils::TimeUtils.humanize_interval(4800)).to eq "1 hour 20 minutes"
    end

    it "works for 1 day" do
      expect(Utils::TimeUtils.humanize_interval(86400)).to eq "24 hours"
    end

    it "works for 1 day plus a bit" do
      expect(Utils::TimeUtils.humanize_interval(86401)).to eq "24 hours"
    end

    it "works for 1 day plus a minute" do
      expect(Utils::TimeUtils.humanize_interval(86460)).to eq "24 hours 1 minute"
    end

    it "works for 5 days" do
      expect(Utils::TimeUtils.humanize_interval(5 * 86400)).to eq "120 hours"
    end
  end
end
