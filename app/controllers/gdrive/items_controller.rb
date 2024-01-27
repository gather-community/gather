# frozen_string_literal: true

module GDrive
  class ItemsController < ApplicationController
    before_action -> { nav_context(:wiki, :gdrive) }

    def new
      authorize(current_community, :setup?, policy_class: SetupPolicy)

      @config = MainConfig.find_by!(community: current_community)
      if !@config
        Rails.logger.error("No config found", community_id: current_community.id)
        return render_not_found
      end

      @item = Item.new
    end

    def create
      authorize(current_community, :setup?, policy_class: SetupPolicy)

      @config = MainConfig.find_by!(community: current_community)
      if !@config
        Rails.logger.error("No config found", community_id: current_community.id)
        return render_not_found
      end

      @item = Item.new(params.require(:gdrive_item).permit(:external_id, :kind))
      @item.gdrive_config_id = @config.id

      # We set this to empty string because it will be immediately fetched and updated
      # when the items page is loaded.
      @item.name = ""

      if @item.save
        flash[:success] = "Item created successfully."
        redirect_to(gdrive_settings_path)
      else
        render(:new)
      end
    end
  end
end
