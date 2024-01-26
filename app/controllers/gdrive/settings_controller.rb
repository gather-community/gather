# frozen_string_literal: true

module GDrive
  class SettingsController < ApplicationController
    before_action -> { nav_context(:wiki, :gdrive) }

    def show
      authorize(current_community, :setup?, policy_class: SetupPolicy)
      @config = MainConfig.find_by!(community: current_community)
      return render_not_found unless @config

      @items_by_kind = {}
      @items_by_kind[:drive] = []
      @items_by_kind[:folder] = []
      @items_by_kind[:file] = []
      @config.items.includes(:item_groups).order(:name).each do |item|
        @items_by_kind[item.kind.to_sym] << item
      end

      wrapper = Wrapper.new(config: @config, google_user_id: @config.org_user_id)
      if wrapper.has_credentials?
        ItemSyncer.new(wrapper, @items_by_kind.values.flatten).sync
      else
        set_auth_error
      end
    rescue Google::Apis::AuthorizationError
      set_auth_error
    end

    private

    def set_auth_error
      @authorization_error = true
      flash.now[:error] = "We encountered an error connecting to Google. The information below may be out of date. " \
        "Please return to the main Google Drive page to re-establish a connection."
    end
  end
end
