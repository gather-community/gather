# frozen_string_literal: true

require "rails_helper"

describe Work::JobPolicy do
  describe "permissions" do
    include_context "policy permissions"
    let(:phase) { "open" }
    let(:period) { create(:work_period, phase: phase) }
    let(:job) { create(:work_job, period: period) }
    let(:record) { job }

    permissions :index?, :show? do
      it_behaves_like "permits users in community only"
    end

    permissions :new?, :edit?, :create?, :update?, :destroy? do
      context "most phases" do
        it_behaves_like "permits admins or special role but not regular users", :work_coordinator
      end

      context "archived phase" do
        let(:phase) { "archived" }
        it_behaves_like "forbids all"
      end
    end
  end

  describe "scope" do
    include_context "policy scopes"
    let(:klass) { Work::Job }
    let(:period) { create(:work_period) }
    let(:periodB) { create(:work_period, community: communityB) }
    let!(:objs_in_community) { create_list(:work_job, 2, period: period) }
    let!(:objs_in_cluster) { create_list(:work_job, 2, period: periodB) }

    it_behaves_like "permits regular users in community"
  end

  describe "permitted attributes" do
    include_context "policy permissions"
    let(:period) { create(:work_period) }
    let(:actor) { work_coordinator }

    subject { Work::JobPolicy.new(actor, Work::Job.new(period: period)).permitted_attributes }

    it do
      expect(subject).to match_array(
        %i[description hours period_id requester_id slot_type hours_per_shift
           time_type title double_signups_allowed] <<
          {shifts_attributes: %i[starts_at ends_at slots id _destroy] <<
            {assignments_attributes: %i[id user_id]}} <<
            {reminders_attributes: %i[abs_rel abs_time rel_magnitude rel_unit_sign note id _destroy]}
      )
    end
  end
end
