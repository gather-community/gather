class ApplicationController < ActionController::Base
  include Pundit, Lensable
  include Concerns::ApplicationController::Csv
  include Concerns::ApplicationController::RequestPreprocessing
  include Concerns::ApplicationController::Setters
  include Concerns::ApplicationController::Loaders
  include Concerns::ApplicationController::UrlHelpers
  include Concerns::ApplicationController::Users
  include Utilities

  # Verify that controller actions are authorized.
  after_action :verify_authorized,  except: :index, unless: :devise_controller?
  after_action :verify_policy_scoped, only: :index

  attr_accessor :current_community

  helper_method :current_community, :current_cluster, :multi_community?, :app_version, :nav_link_builder

  def nav_link_builder
    @nav_link_builder ||= Nav::LinkBuilder.new
  end

  protected

  def nav_context(section, subsection = nil)
    @context = {section: section, subsection: subsection}
    nav_link_builder.context = {section: section, subsection: subsection}
  end

  def app_version
    @app_version ||= File.read(Rails.root.join("VERSION"))
  end

  def current_cluster
    current_tenant
  end
end
