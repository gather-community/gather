# frozen_string_literal: true

module GDrive
  class ItemsController < ApplicationController
    include Destructible

    before_action -> { nav_context(:wiki, :gdrive) }
    before_action :load_config

    helper_method :sample_item

    def index
      authorize(current_community, :setup?, policy_class: SetupPolicy)
      skip_policy_scope

      wrapper = Wrapper.new(config: @config, google_user_id: @config.org_user_id)
      if wrapper.has_credentials?
        # Order should be stable for testing purposes
        items = @config.items.order(:external_id).to_a
        ItemSyncer.new(wrapper, items).sync if items.any?
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
    rescue Google::Apis::AuthorizationError, Signet::AuthorizationError
      set_auth_error
    end

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

    def sample_item
      @sample_item ||= Item.new(gdrive_config: @config)
    end

    def load_config
      @config = MainConfig.find_by(community: current_community)
      if !@config
        Rails.logger.error("No config found", community_id: current_community.id)
        render_not_found
      end
    end

    def set_auth_error
      @config.tokens.destroy_all
      @authorization_error = true
    end

    # Pundit built-in helper doesn't work due to namespacing
    def item_params
      params.require(:gdrive_item).permit(policy(@item).permitted_attributes)
    end
  end
end
