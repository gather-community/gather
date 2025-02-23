# frozen_string_literal: true

require "rails_helper"

describe Work::SynopsisDecorator do
  let(:synopsis) do
    described_class.new(
      double({
        done?: attribs[:done],
        empty?: false,
        for_user: nil,
        for_household: nil,
        staggering: nil
      }.merge(attribs))
    )
  end
  let(:regular) { Work::Synopsis::REGULAR_BUCKET }
  subject { synopsis.to_s }

  context "by_user quota" do
    context "no full community jobs" do
      context "zero signups" do
        let(:attribs) { {for_user: [{bucket: regular, got: 0, ttl: 28.43, ok: false}], done: false} }
        it do
          is_expected.to eq("You have signed up for <b>0/28.5</b> hours.")
        end
      end

      context "partially complete" do
        let(:attribs) { {for_user: [{bucket: regular, got: 9.0, ttl: 28.43, ok: false}], done: false} }
        it do
          is_expected.to eq("You have signed up for <b>9/28.5</b> hours.")
        end
      end

      context "complete" do
        let(:attribs) { {for_user: [{bucket: regular, got: 29, ttl: 28.43, ok: true}], done: true} }
        it do
          is_expected.to eq("You have signed up for <i>29/28.5</i> hours. <i>You&#39;re all set!</i>")
        end
      end
    end

    context "one full community job" do
      let(:job) { create(:work_job, title: "Foo Bar", slot_type: "full_multiple") }

      context "zero signups" do
        let(:attribs) do
          {for_user: [{bucket: regular, got: 0, ttl: 28.43, ok: false},
                      {bucket: job, got: 0, ttl: 6, ok: false}],
           done: false}
        end
        it do
          is_expected.to eq("You have signed up for <b>0/28.5</b> regular hours " \
                            "and <b>0/6</b> Foo Bar hours.")
        end
      end

      context "partially complete" do
        let(:attribs) do
          {for_user: [{bucket: regular, got: 28.21, ttl: 28.43, ok: true},
                      {bucket: job, got: 2, ttl: 6, ok: false}],
           done: false}
        end
        it do
          is_expected.to eq("You have signed up for <i>28.5/28.5</i> regular hours " \
                            "and <b>2/6</b> Foo Bar hours.")
        end
      end

      context "complete" do
        let(:attribs) do
          {for_user: [{bucket: regular, got: 28.21, ttl: 28.43, ok: true},
                      {bucket: job, got: 6, ttl: 6, ok: true}],
           done: true}
        end
        it do
          is_expected.to eq("You have signed up for <i>28.5/28.5</i> regular hours " \
                            "and <i>6/6</i> Foo Bar hours. <i>You&#39;re all set!</i>")
        end
      end
    end

    context "two full community jobs" do
      let(:job1) { create(:work_job, title: "Foo Bar", slot_type: "full_multiple") }
      let(:job2) { create(:work_job, title: "Ba. Qux", slot_type: "full_single") }

      context "zero signups" do
        let(:attribs) do
          {for_user: [
            {bucket: regular, got: 0, ttl: 28.43, ok: false},
            {bucket: job1, got: 3, ttl: 6, ok: false},
            {bucket: job2, got: 8, ttl: 8, ok: true}
          ], done: false}
        end
        it do
          is_expected.to eq("You have signed up for <b>0/28.5</b> regular hours, " \
                            "<b>3/6</b> Foo Bar hours, and <i>8/8</i> Ba. Qux hours.")
        end
      end
    end
  end

  context "by_household quota" do
    let(:job) { create(:work_job, title: "Foo Bar", slot_type: "full_multiple") }

    context "zero signups" do
      let(:attribs) do
        {for_user: [{bucket: regular, got: 0, ttl: 28.43, ok: false},
                    {bucket: job, got: 0, ttl: 6, ok: false}],
         for_household: [{bucket: regular, got: 0, ttl: 56.86, ok: false},
                         {bucket: job, got: 0, ttl: 12, ok: false}],
         done: false}
      end
      it do
        is_expected.to eq("You have signed up for <b>0/28.5</b> regular hours " \
                          "and <b>0/6</b> Foo Bar hours. Your household has <b>0/57</b> regular hours " \
                          "and <b>0/12</b> Foo Bar hours.")
      end
    end

    context "partially complete" do
      let(:attribs) do
        {for_user: [{bucket: regular, got: 4.2, ttl: 28.43, ok: false},
                    {bucket: job, got: 6, ttl: 6, ok: true}],
         for_household: [{bucket: regular, got: 4.2, ttl: 56.86, ok: false},
                         {bucket: job, got: 6, ttl: 12, ok: false}],
         done: false}
      end
      it do
        is_expected.to eq("You have signed up for <b>4.5/28.5</b> regular hours " \
                          "and <i>6/6</i> Foo Bar hours. Your household has <b>4.5/57</b> regular hours " \
                          "and <b>6/12</b> Foo Bar hours.")
      end
    end

    context "household complete even though user not" do
      let(:attribs) do
        {for_user: [{bucket: regular, got: 25, ttl: 28.43, ok: true},
                    {bucket: job, got: 6, ttl: 6, ok: true}],
         for_household: [{bucket: regular, got: 58, ttl: 56.86, ok: true},
                         {bucket: job, got: 12, ttl: 12, ok: true}],
         done: true}
      end
      it do
        is_expected.to eq("You have signed up for <i>25/28.5</i> regular hours " \
                          "and <i>6/6</i> Foo Bar hours. Your household has <i>58/57</i> regular hours " \
                          "and <i>12/12</i> Foo Bar hours. <i>You&#39;re all set!</i>")
      end
    end
  end

  context "with staggering" do
    let(:buckets) { [{bucket: regular, got: 0, ttl: 28.43, ok: false}] }
    let(:done) { false }
    let(:attribs) { {for_user: buckets, done: done, staggering: staggering} }
    let(:next_starts_at) { Time.zone.parse("2018-08-15 19:30") }
    let(:now) { next_starts_at - 2.hours }

    around do |example|
      Timecop.freeze(now) { example.run }
    end

    context "with next_limit and zero prev_limit" do
      let(:staggering) { {prev_limit: 0, next_limit: 5, next_starts_at: next_starts_at} }

      context "on choosing day" do
        it "gives time only " do
          is_expected.to eq("You have signed up for <b>0/28.5</b> hours. " \
                            "You can start choosing jobs at 7:30pm.")
        end
      end

      context "on other day" do
        let(:now) { next_starts_at - 2.days }
        it "gives date and time" do
          is_expected.to eq("You have signed up for <b>0/28.5</b> hours. " \
                            "You can start choosing jobs on Wed Aug 15 7:30pm.")
        end
      end

      context "if already set" do
        let(:buckets) { [{bucket: regular, got: 30, ttl: 28.43, ok: true}] }
        let(:done) { true }

        it "doesn't add staggering info" do
          is_expected.to eq("You have signed up for <i>30/28.5</i> hours. <i>You&#39;re all set!</i>")
        end
      end
    end

    context "with next_limit and prev_limit" do
      let(:staggering) { {prev_limit: 15, next_limit: 20, next_starts_at: next_starts_at} }
      it do
        is_expected.to eq("You have signed up for <b>0/28.5</b> hours. " \
                          "Your round limit is 15 hours and will rise to 20 at 7:30pm.")
      end
    end

    context "with prev_limit only" do
      let(:staggering) { {prev_limit: 15, next_limit: nil, next_starts_at: next_starts_at} }
      it do
        is_expected.to eq("You have signed up for <b>0/28.5</b> hours. " \
                          "Your round limit is 15 hours until 7:30pm.")
      end
    end

    context "with no limit" do
      let(:staggering) { {prev_limit: nil, next_limit: nil, next_starts_at: nil} }
      it do
        is_expected.to eq("You have signed up for <b>0/28.5</b> hours.")
      end
    end
  end
end
