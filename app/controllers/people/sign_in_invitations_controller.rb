# frozen_string_literal: true

module People
  # Handles batch requests to invite people to sign in.
  class SignInInvitationsController < ApplicationController
    def new
      authorize(sample_user, policy_class: SignInInvitationsPolicy)
      @users = User.in_community(current_community).adults.active.by_name
    end

    # Expects params[to_invite] = ["1", "5", ...]
    def create
      authorize(sample_user, policy_class: SignInInvitationsPolicy)
      if params[:to_invite].blank?
        flash[:error] = "You didn't select any users."
      else
        People::SignInInvitationJob.perform_later(current_community.id, params[:to_invite])
        flash[:success] = t("people.sign_in_invitations.sent", count: params[:to_invite].size)
        redirect_to(users_path)
      end
    end

    private

    def sample_user
      User.new(household: Household.new(community: current_community))
    end
  end
end
