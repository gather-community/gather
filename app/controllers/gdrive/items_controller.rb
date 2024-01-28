# frozen_string_literal: true

module GDrive
  class ItemsController < ApplicationController
    include Destructible

    before_action -> { nav_context(:wiki, :gdrive) }
    before_action :load_config, only: %i[new create]

    def index
      authorize(current_community, :setup?, policy_class: SetupPolicy)
      skip_policy_scope

      @config = MainConfig.find_by!(community: current_community)
      return render_not_found unless @config

      wrapper = Wrapper.new(config: @config, google_user_id: @config.org_user_id)
      if wrapper.has_credentials?
        ItemSyncer.new(wrapper, @config.items).sync
      else
        set_auth_error
      end

      @items_by_kind = {}
      @items_by_kind[:drive] = []
      @items_by_kind[:folder] = []
      @items_by_kind[:file] = []
      @config.items.includes(:item_groups).order(:name).each do |item|
        @items_by_kind[item.kind.to_sym] << item
      end
    rescue Google::Apis::AuthorizationError
      set_auth_error
    end

    def new
      @item = Item.new(gdrive_config: @config)

      authorize(@item)
    end

    def create
      @item = Item.new(params.require(:gdrive_item).permit(:external_id, :kind))
      @item.gdrive_config_id = @config.id

      authorize(@item)

      # We set this to empty string because it will be immediately fetched and updated
      # when the items page is loaded.
      @item.name = ""

      if @item.save
        flash[:success] = "Item created successfully."
        redirect_to(gdrive_items_path)
      else
        render(:new)
      end
    end

    protected

    def klass
      GDrive::Item
    end

    private

    def load_config
      @config = MainConfig.find_by!(community: current_community)
      if !@config
        Rails.logger.error("No config found", community_id: current_community.id)
        render_not_found
      end
    end

    def set_auth_error
      @authorization_error = true
      flash.now[:error] = "We encountered an error connecting to Google. The information below may be out of date. " \
        "Please return to the main Google Drive page to re-establish a connection."
    end
  end
end
