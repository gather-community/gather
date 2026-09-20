# frozen_string_literal: true

require "rails_helper"

# Signup pages are period-scoped (/work/:period_slug/signups/:id). The round limit is computed for
# the period in the URL, so if the shift didn't have to belong to that period, naming a different
# one would get the limit computed against the wrong period — and silently skipped.
describe "work shift signup request" do
  let(:actor) { create(:user) }
  let(:prev_limit) { 1 }
  let(:period) do
    create(:work_period, phase: "open", quota_type: "by_person", quota: 20, pick_type: "staggered",
                         auto_open_time: Time.current - 1.hour, round_duration: 5,
                         max_rounds_per_worker: 3, workers_per_round: 10)
  end
  # A second period the actor could name in the URL instead. Not staggered, so a synopsis built for
  # it carries no round limit at all.
  let!(:other_period) { create(:work_period, phase: "open") }
  let(:job) { create(:work_job, period: period, hours: 3) }
  let(:shift) { job.shifts.first }

  # The request clears the tenant on its way out, so post-request reads have to restore it.
  def signed_up_user_ids
    with_default_tenant { shift.reload.assignments.map(&:user_id) }
  end

  before do
    period.shares.create!(user: actor, portion: 1)
    allow(Work::RoundCalculator).to receive(:new)
      .and_return(double(prev_limit: prev_limit, next_limit: nil, next_starts_at: nil))
    use_user_subdomain(actor)
    sign_in(actor)
  end

  describe "signup" do
    context "when the shift is over the round limit" do
      let(:prev_limit) { 1 }

      it "refuses via the shift's own period" do
        post(signup_work_period_shift_path(period, shift))
        expect(flash[:error]).to eq("You have exceeded your round limit.")
        expect(signed_up_user_ids).to be_empty
      end

      it "refuses when another period is named in the URL" do
        expect do
          post(signup_work_period_shift_path(other_period, shift))
        end.to raise_error(ActiveRecord::RecordNotFound)
        expect(signed_up_user_ids).to be_empty
      end
    end

    context "when the shift is within the round limit" do
      let(:prev_limit) { 10 }

      it "signs up via the shift's own period" do
        post(signup_work_period_shift_path(period, shift))
        expect(flash[:error]).to be_nil
        expect(signed_up_user_ids).to eq([actor.id])
      end

      # The URL has to mean what it says regardless of whether the limit would have allowed it.
      it "still refuses when another period is named in the URL" do
        expect do
          post(signup_work_period_shift_path(other_period, shift))
        end.to raise_error(ActiveRecord::RecordNotFound)
        expect(signed_up_user_ids).to be_empty
      end
    end

    context "with a slug that matches no period" do
      it "renders not found instead of erroring on the missing period" do
        post("/work/nonesuch/signups/#{shift.id}/signup")
        expect(response).to have_http_status(:not_found)
        expect(signed_up_user_ids).to be_empty
      end
    end
  end

  describe "unsignup" do
    let!(:assignment) { create(:work_assignment, shift: shift, user: actor) }

    it "removes the signup via the shift's own period" do
      delete(unsignup_work_period_shift_path(period, shift))
      expect(signed_up_user_ids).to be_empty
    end

    it "refuses when another period is named in the URL" do
      expect do
        delete(unsignup_work_period_shift_path(other_period, shift))
      end.to raise_error(ActiveRecord::RecordNotFound)
      expect(signed_up_user_ids).to eq([actor.id])
    end
  end
end
