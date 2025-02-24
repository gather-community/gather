# frozen_string_literal: true

module Groups
  module Mailman
    class ListsController < ApplicationController
      def sync
        list = List.find(params[:id])
        authorize(list)
        ListSyncJob.perform_later(list_id: list.id)
        flash[:success] =
          "List sync started. Please wait a few moments for it to complete and refresh the page."
        redirect_to(groups_group_path(list.group))
      end
    end
  end
end
