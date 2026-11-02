# frozen_string_literal: true

module Groups
  module Mailman
    class ListsController < ApplicationController
      def sync
        list = List.find(params[:id])
        authorize(list)
        ListSyncJob.perform_later(list_id: list.id)
        flash[:success] = t("groups.list_sync_started")
        redirect_to(groups_group_path(list.group))
      end
    end
  end
end
