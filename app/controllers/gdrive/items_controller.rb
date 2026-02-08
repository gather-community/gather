# frozen_string_literal: true

module GDrive
  class ItemsController < ApplicationController
    include Destructible

    before_action -> { nav_context(:wiki, :gdrive) }
    before_action :load_config

    def new
      @item = Item.new(gdrive_config: @config)

      authorize(@item)
    end

    def create
      @item = Item.new(gdrive_config: @config)
      @item.assign_attributes(item_params)

      authorize(@item)

      # We set this to empty string because it will be immediately fetched and updated
      # when the items page is loaded.
      @item.name = ""

      if @item.save
        flash[:success] = "Item created successfully."
        redirect_to(gdrive_config_path)
      else
        render(:new)
      end
    end

    def destroy
      simple_action(:destroy, redirect: gdrive_config_path)
    end

    protected

    def klass
      GDrive::Item
    end

    private

    def load_config
      @config = Config.find_by(community: current_community)
      if !@config
        Rails.logger.error("No config found", community_id: current_community.id)
        render_not_found
      end
    end

    # Pundit built-in helper doesn't work due to namespacing
    def item_params
      params.require(:gdrive_item).permit(policy(@item).permitted_attributes)
    end
  end
end
