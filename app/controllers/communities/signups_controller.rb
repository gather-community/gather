# frozen_string_literal: true

class Communities::SignupsController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[new create submitted]
  skip_after_action :verify_authorized, only: %i[new create submitted]

  def index
    authorize(Communities::Signup)
    prepare_lenses({:"communities/signup_status" => {initial_selection: :pending}})
    @signups = policy_scope(Communities::Signup)
      .where(status_filter)
      .order(created_at: :desc)
  end

  def new
    @form = Communities::SignupForm.new(action: :new)
  end

  def create
    @form = Communities::SignupForm.new(action: :create, params: params.require(:communities_signup))
    unless @form.valid?
      render(:new) and return
    end
    unless verify_hcaptcha
      @form.errors.add(:hcaptcha_verified, "Captcha verification failed. Please try again.")
      render(:new) and return
    end
    if @form.save
      Communities::SignupMailer.notify_approvers(@form.signup).deliver_later
      redirect_to(submitted_communities_signups_path, flash: {contact_email: @form.signup.contact_email})
    else
      render(:new)
    end
  end

  def submitted
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
      redirect_to(communities_signups_path, notice: "Application approved. Community setup is underway.")
    when "deny"
      @signup.deny!(current_user, message: @action_form.message)
      Communities::SignupMailer.application_denied(@signup).deliver_now
      redirect_to(communities_signups_path, notice: "Application denied.")
    end
  end

  protected

  def apex_domain_only
    true
  end

  private

  def status_filter
    status = lenses[:status].selection
    status == :all ? {} : {status: status}
  end
end
