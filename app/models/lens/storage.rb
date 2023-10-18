# frozen_string_literal: true

module Lens
  # Manages storage for lenses across communities, controllers, and actions.
  class Storage
    attr_accessor :session, :community_id, :root_store, :community_store, :controller_path, :action_name

    LENS_VERSION = 6
    EXPIRY_TIME = 30.minutes

    def initialize(session:, community_id:, controller_path:, action_name:, persist:, reset: false)
      self.session = persist ? session : {}
      self.community_id = community_id
      self.controller_path = controller_path
      self.action_name = action_name

      # Get root store if it exists since the reset checks need it
      @root_store = session[:lenses]

      reset_stores if reset || old_version? || expired?

      # Init root and cmty stores if they don't exist already.
      @root_store = (session[:lenses] ||= {"V" => LENS_VERSION})
      @community_store = (root_store[community_id.to_s] ||= {})

      root_store["T"] = (Time.current.to_f / 60).ceil
    end

    # The portion of the community_store for global lenses.
    def global_store
      @global_store ||= (community_store["G"] ||= {})
    end

    # The portion of the community_store for the current controller and action.
    def action_store
      @action_store ||= (community_store["#{controller_path}__#{action_name}"] ||= {})
    end

    private

    def reset_stores
      @root_store = nil
      @community_store = nil
      session.delete(:lenses)
    end

    def expired?
      root_store && ((root_store["T"] || 0) + (EXPIRY_TIME / 1.minute) < Time.current.to_f / 60)
    end

    def old_version?
      root_store && (root_store["V"] || 1) < LENS_VERSION
    end
  end
end
