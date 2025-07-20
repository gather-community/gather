# frozen_string_literal: true

class DomainsController < ApplicationController
  include Destructible

  before_action -> { nav_context(:groups) }
  helper_method :sample_domain
  decorates_assigned :domain

  def index
    authorize(sample_domain)
    @domains = policy_scope(Domain).in_community(current_community)
  end

  def show
    @domain = Domain.find(params[:id])
    authorize(@domain)
  end

  def new
    @domain = sample_domain
    authorize(@domain)
    prep_form_vars
  end

  def create
    @domain = sample_domain
    @domain.assign_attributes(domain_params)
    authorize(@domain)
    if @domain.save
      flash[:success] = "Domain created successfully."
      redirect_to(domains_path)
    else
      prep_form_vars
      render(:new)
    end
  end

  protected

  def klass
    Domain
  end

  private

  def sample_domain
    Domain.new(communities: [current_community])
  end

  def prep_form_vars
    if policy(@domain).permitted_attributes.include?(community_ids: []) && multi_community?
      @community_options = Community.by_name_with_first(current_community)
    end
  end

  # Pundit built-in helper doesn't work due to namespacing
  def domain_params
    params.require(:domain).permit(policy(@domain).permitted_attributes)
  end
end
