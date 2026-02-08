# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Lensable
  include Pundit::Authorization
  include ApplicationControllable::Csv
  include ApplicationControllable::RequestPreprocessing
  include ApplicationControllable::Setters
  include ApplicationControllable::Loaders
  include ApplicationControllable::UrlHelpers
  include ApplicationControllable::Users
  include MultiCommunityCheck

  # Verify that controller actions are authorized.
  after_action :verify_authorized, except: :index, unless: :devise_controller?
  after_action :verify_policy_scoped, only: :index

  attr_accessor :current_community

  helper_method :current_community, :current_cluster, :multi_community?, :own_cluster?, :nav_builder

  def current_cluster
    current_tenant
  end

  def own_cluster?
    current_cluster == current_user.cluster
  end

  protected

  def nav_builder
    @nav_builder ||= Nav::Builder.new
  end

  def nav_context(*levels)
    nav_builder.context = levels
  end

  # Builds a serializer for the given object using the Attributes adapter.
  # Useful for getting JSON to pass into a JS view, for instance.
  # Respects the key_transform setting.
  def build_attribute_serializer(obj, **options)
    options.merge!(adapter: ActiveModelSerializers::Adapter::Attributes)
    ActiveModelSerializers::SerializableResource.new(obj, options)
  end
end
