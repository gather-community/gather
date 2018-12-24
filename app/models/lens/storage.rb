# frozen_string_literal: true

module Lens
  class Storage
    attr_accessor :session, :community_id, :controller_path, :action_name

    LENS_VERSION = 5

    def initialize(session:, community_id:, controller_path:, action_name:)
      self.session = session
      self.community_id = community_id
      self.controller_path = controller_path
      self.action_name = action_name
      reset_on_version_upgrade
    end

    def root_store
      @root_store ||= (session[:lenses] ||= {"V" => LENS_VERSION})
    end

    def community_store
      @community_store ||= (root_store[community_id.to_s] ||= {})
    end

    # The portion of the community_store for global lenses.
    def global_store
      @global_store ||= (community_store["G"] ||= {})
    end

    # The portion of the community_store for the current controller and action.
    def action_store
      @action_store ||= (community_store["#{controller_path}__#{action_name}"] ||= {})
    end

    def reset
      @root_store = nil
      session.delete(:lenses)
    end

    private

    def reset_on_version_upgrade
      reset_root_store if (root_store["V"] || 1) < LENS_VERSION
    end
  end
end
