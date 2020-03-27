# frozen_string_literal: true

class SingleSignOnController < ApplicationController
  # sso requests may be to the apex domain or subdomain.
  skip_before_action :ensure_subdomain, only: :sign_on

  # Impersonation doesn't make sense for SSO since you can't see the impersonation banner
  # and you may arrive at the Mailman UI from a different path and forget that you are impersonating someone.
  # In future we could present a confirmation screen before continuing with login, but for now it's simpler
  # to just ignore impersonation.
  skip_before_action :handle_impersonation, only: :sign_on

  def sign_on
    authorize(:single_sign_on)
    handler = build_handler
    handler.email = current_user.email
    handler.external_id = current_user.id
    handler.name = current_user.decorate.full_name
    handler.username = handler.name
    handler.custom_fields[:first_name] = current_user.first_name
    handler.custom_fields[:last_name] = current_user.last_name

    redirect_to(handler.to_url)
  rescue Pundit::NotAuthorizedError
    render_forbidden
  rescue DiscourseSingleSignOn::ParseError, DiscourseSingleSignOn::SignatureError => e
    render(plain: e, status: :unprocessable_entity)
  end

  private

  def build_handler
    if current_community.nil?
      build_handler_with_secret(Settings.single_sign_on.secret)
    else
      begin
        build_handler_with_secret(current_community.sso_secret || "")
      rescue DiscourseSingleSignOn::SignatureError
        build_handler_with_secret(current_community.cluster.sso_secret || "")
      end
    end
  end

  def build_handler_with_secret(secret)
    # Expects client to specify return URL.
    DiscourseSingleSignOn.new(payload: params[:sso], signature: params[:sig], secret: secret)
  end
end
