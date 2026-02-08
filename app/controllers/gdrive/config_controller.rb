# frozen_string_literal: true

module GDrive
  class ConfigController < ApplicationController
    include AuthUrlable

    before_action -> { nav_context(:wiki, :gdrive) }
    helper_method :sample_item, :sample_operation

    def index
      authorize(current_community, :setup?, policy_class: SetupPolicy)
      skip_policy_scope

      @config = Config.find_by(community: current_community) || Config.new
      @migration_operation = Migration::Operation.find_by(community: current_community)

      if @config.persisted?
        # We need the callback_url here b/c we may need to generate the auth_url in the else branch below
        wrapper = Wrapper.new(config: @config, google_user_id: @config.org_user_id,
          callback_url: gdrive_setup_auth_callback_url(host: Settings.url.host))

        if wrapper.has_credentials?
          # Order should be stable for testing purposes
          items = @config.items.order(:external_id).to_a
          ItemSyncer.new(wrapper, items).sync if items.any?
        else
          set_auth_required
          setup_auth_url(wrapper: wrapper)
        end

        @items_by_kind = {}
        @items_by_kind[:drive] = []
        @items_by_kind[:folder] = []
        @items_by_kind[:file] = []
        @config.items.includes(:item_groups).order(:name).each do |item|
          @items_by_kind[item.kind.to_sym] << item
        end
      else
        set_auth_required
      end
    rescue Google::Apis::AuthorizationError, Signet::AuthorizationError => error
      Rails.logger.error("There was an authorization error connecting to Google Drive", error: error.to_s)
      set_auth_required
    end

    def guide
      authorize(current_community, :setup?, policy_class: SetupPolicy)
    end

    def update
      authorize(current_community, :setup?, policy_class: SetupPolicy)
      @config = Config.find_by(community: current_community) || Config.new(community: current_community)
      @config.assign_attributes(config_params)
      if @config.save
        flash[:success] = "Config updated successfully."
        redirect_to(gdrive_config_path)
      else
        set_auth_required if @config.new_record?
        render(:index)
      end
    end

    private

    def sample_item
      return nil if @config.nil?
      @sample_item ||= Item.new(gdrive_config: @config)
    end

    def sample_operation
      @sample_operation ||= Migration::Operation.new(community: current_community)
    end

    def set_auth_required
      @config.tokens.destroy_all if @config.persisted?
      @auth_required = true
    end

    # Pundit built-in helper doesn't work due to namespacing
    def config_params
      params.require(:gdrive_config).permit(policy(@config).permitted_attributes)
    end
  end
end
