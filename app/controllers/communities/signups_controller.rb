# frozen_string_literal: true

# The public application form for new communities. Reviewing applications is Admin::SignupsController.
class Communities::SignupsController < ApplicationController
  skip_before_action :authenticate_user!
  skip_after_action :verify_pundit_authorization

  def new
    @form = Communities::SignupForm.new(action: :new)
    # Start with the language this page is in, which follows the browser or the footer's language menu.
    @form.signup.locale = I18n.locale.to_s if Gather::Locales.enabled?(nil)
  end

  def create
    @form = Communities::SignupForm.new(action: :create, params: params.require(:communities_signup))
    unless @form.valid?
      render(:new) and return
    end
    unless verify_hcaptcha
      @form.errors.add(:hcaptcha_verified, t("communities.signups.captcha_failed"))
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

  protected

  def apex_domain_only
    true
  end
end
