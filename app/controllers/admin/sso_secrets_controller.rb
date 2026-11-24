# frozen_string_literal: true

module Admin
  # Shows and resets the community's single sign-on secret, which outside apps use to sign people in
  # with their Gather account (see SingleSignOnController).
  class SsoSecretsController < ApplicationController
    def show
      authorize(current_community, :show_sso_secret?, policy_class: SettingsPolicy)
      @community = current_community
    end

    def reset
      authorize(current_community, :reset_sso_secret?, policy_class: SettingsPolicy)
      current_community.reset_sso_secret!
      flash[:success] = t("admin.sso_secrets.reset_success")
      redirect_to(admin_sso_secret_path)
    end
  end
end
