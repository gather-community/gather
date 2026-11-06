# frozen_string_literal: true

module Admin
  # Operator pages for reviewing applications for new communities. The public application form is
  # Communities::SignupsController.
  class SignupsController < AdminController
    before_action -> { nav_context(:communities, :signups) }

    def index
      authorize(Communities::Signup)
      prepare_lenses({"communities/signup_status": {initial_selection: :pending}})
      @signups = policy_scope(Communities::Signup)
        .where(status_filter)
        .order(created_at: :desc)
    end

    def review
      @signup = Communities::Signup.find(params[:id])
      authorize(@signup)
      @action_form = Communities::SignupActionForm.new
    end

    def act
      @signup = Communities::Signup.find(params[:id])
      authorize(@signup, :act?)
      @action_form = Communities::SignupActionForm.new(
        params.require(:communities_signup_action).permit(:decision, :message)
      )
      unless @action_form.valid?
        render(:review) and return
      end
      case @action_form.decision
      when "approve"
        @signup.approve!(current_user, message: @action_form.message)
        Communities::SignupApprovalJob.perform_later(@signup.id)
        redirect_to(admin_signups_path, notice: t("communities.signups.approved"))
      when "deny"
        @signup.deny!(current_user, message: @action_form.message)
        Communities::SignupMailer.application_denied(@signup).deliver_now
        redirect_to(admin_signups_path, notice: t("communities.signups.denied"))
      end
    end

    private

    def status_filter
      status = lenses[:status].selection
      (status == :all) ? {} : {status: status}
    end
  end
end
