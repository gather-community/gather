# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Lensable
  include Pundit
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
  alias current_cluster current_tenant

  helper_method :current_community, :current_cluster, :multi_community?, :app_version, :nav_builder

  def current_cluster
    current_tenant
  end

  protected

  def nav_builder
    @nav_builder ||= Nav::Builder.new
  end

  def nav_context(main, sub_item = nil, sub_sub_item = nil)
    nav_builder.context = {main: main, sub_item: sub_item, sub_sub_item: sub_sub_item}
  end

  def app_version
    @app_version ||= File.read(Rails.root.join("VERSION"))
  end
end
