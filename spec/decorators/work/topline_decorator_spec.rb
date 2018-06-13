# frozen_string_literal: true

require "rails_helper"

describe Work::ToplineDecorator do
  let(:builder) { described_class.new(double(summary: summary)) }
  let(:regular) { OpenStruct.new(title: "regular") }
  subject { builder.to_s }

  context "by_user quota" do
    context "no full community jobs" do
      context "zero signups" do
        let(:summary) { {self: [{bucket: regular, got: 0, ttl: 28.43, ok: false}], done: false} }
        it do
          is_expected.to eq "You have signed up for <b>0/28.5</b> hours."
        end
      end

      context "partially complete" do
        let(:summary) { {self: [{bucket: regular, got: 9.0, ttl: 28.43, ok: false}], done: false} }
        it do
          is_expected.to eq "You have signed up for <b>9/28.5</b> hours."
        end
      end

      context "complete" do
        let(:summary) { {self: [{bucket: regular, got: 29, ttl: 28.43, ok: true}], done: true} }
        it do
          is_expected.to eq "You have signed up for <i>29/28.5</i> hours. <i>You&#39;re all set!</i>"
        end
      end
    end

    context "one full community job" do
      let(:job) { create(:work_job, title: "Foo Bar", slot_type: "full_multiple") }

      context "zero signups" do
        let(:summary) do
          {self: [{bucket: regular, got: 0, ttl: 28.43, ok: false},
                  {bucket: job, got: 0, ttl: 6, ok: false}],
           done: false}
        end
        it do
          is_expected.to eq "You have signed up for <b>0/28.5</b> regular hours "\
            "and <b>0/6</b> Foo Bar hours."
        end
      end

      context "partially complete" do
        let(:summary) do
          {self: [{bucket: regular, got: 28.21, ttl: 28.43, ok: true},
                  {bucket: job, got: 2, ttl: 6, ok: false}],
           done: false}
        end
        it do
          is_expected.to eq "You have signed up for <i>28.5/28.5</i> regular hours "\
            "and <b>2/6</b> Foo Bar hours."
        end
      end

      context "complete" do
        let(:summary) do
          {self: [{bucket: regular, got: 28.21, ttl: 28.43, ok: true},
                  {bucket: job, got: 6, ttl: 6, ok: true}],
           done: true}
        end
        it do
          is_expected.to eq "You have signed up for <i>28.5/28.5</i> regular hours "\
            "and <i>6/6</i> Foo Bar hours. <i>You&#39;re all set!</i>"
        end
      end
    end

    context "two full community jobs" do
      let(:job1) { create(:work_job, title: "Foo Bar", slot_type: "full_multiple") }
      let(:job2) { create(:work_job, title: "Ba. Qux", slot_type: "full_single") }

      context "zero signups" do
        let(:summary) do
          {self: [
            {bucket: regular, got: 0, ttl: 28.43, ok: false},
            {bucket: job1, got: 3, ttl: 6, ok: false},
            {bucket: job2, got: 8, ttl: 8, ok: true}
          ], done: false}
        end
        it do
          is_expected.to eq "You have signed up for <b>0/28.5</b> regular hours, "\
            "<b>3/6</b> Foo Bar hours, and <i>8/8</i> Ba. Qux hours."
        end
      end
    end
  end

  context "by_household quota" do
    let(:job) { create(:work_job, title: "Foo Bar", slot_type: "full_multiple") }

    context "zero signups" do
      let(:summary) do
        {self:      [{bucket: regular, got: 0, ttl: 28.43, ok: false},
                     {bucket: job, got: 0, ttl: 6, ok: false}],
         household: [{bucket: regular, got: 0, ttl: 56.86, ok: false},
                     {bucket: job, got: 0, ttl: 12, ok: false}],
         done:      false}
      end
      it do
        is_expected.to eq "You have signed up for <b>0/28.5</b> regular hours "\
          "and <b>0/6</b> Foo Bar hours. Your household has <b>0/57</b> regular hours "\
          "and <b>0/12</b> Foo Bar hours."
      end
    end

    context "partially complete" do
      let(:summary) do
        {self:      [{bucket: regular, got: 4.2, ttl: 28.43, ok: false},
                     {bucket: job, got: 6, ttl: 6, ok: true}],
         household: [{bucket: regular, got: 4.2, ttl: 56.86, ok: false},
                     {bucket: job, got: 6, ttl: 12, ok: false}],
         done:      false}
      end
      it do
        is_expected.to eq "You have signed up for <b>4.5/28.5</b> regular hours "\
          "and <i>6/6</i> Foo Bar hours. Your household has <b>4.5/57</b> regular hours "\
          "and <b>6/12</b> Foo Bar hours."
      end
    end

    context "household complete even though user not" do
      let(:summary) do
        {self:      [{bucket: regular, got: 25, ttl: 28.43, ok: true},
                     {bucket: job, got: 6, ttl: 6, ok: true}],
         household: [{bucket: regular, got: 58, ttl: 56.86, ok: true},
                     {bucket: job, got: 12, ttl: 12, ok: true}],
         done:      true}
      end
      it do
        is_expected.to eq "You have signed up for <i>25/28.5</i> regular hours "\
          "and <i>6/6</i> Foo Bar hours. Your household has <i>58/57</i> regular hours "\
          "and <i>12/12</i> Foo Bar hours. <i>You&#39;re all set!</i>"
      end
    end
  end
end
