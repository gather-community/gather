# frozen_string_literal: true

module People
  # Lets users choose which notifications they get.
  class NotificationPreferencesController < ApplicationController
    def show
      authorize(current_user, :update_notification_prefs?)
      prepare_form
    end

    def update
      authorize(current_user, :update_notification_prefs?)
      prepare_form
      @form.update(params.require(:people_notification_preferences))
      flash[:success] = t("people.notification_preferences.updated")
      redirect_to(notification_preferences_path)
    end

    private

    def prepare_form
      @form = NotificationPreferencesForm.new(user: current_user, policy: policy(current_user))
      @groups_with_lists = Groups::Group.active.with_user(current_user)
        .where(id: Groups::Mailman::List.select(:group_id)).includes(mailman_list: :domain).by_name
    end
  end
end
