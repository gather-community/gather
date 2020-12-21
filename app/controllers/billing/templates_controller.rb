# frozen_string_literal

module Billing
  class TemplatesController < ApplicationController
    include Destructible
    include TransactionEditable

    before_action -> { nav_context(:billing, :templates) }

    decorates_assigned :templates, :template
    helper_method :sample_template, :member_type_options

    def index
      authorize(sample_template)
      @templates = policy_scope(Template).in_community(current_community).by_description
    end

    def new
      @template = sample_template
      authorize(@template)
    end

    def edit
      @template = Template.find(params[:id])
      authorize(@template)
    end

    def create
      @template = sample_template
      @template.assign_attributes(template_params)
      authorize(@template)
      if @template.save
        flash[:success] = "Template created successfully."
        redirect_to(billing_templates_path)
      else
        render(:new)
      end
    end

    def update
      @template = Template.find(params[:id])
      authorize(@template)
      if @template.update(template_params)
        flash[:success] = "Template updated successfully."
        redirect_to(billing_templates_path)
      else
        render(:edit)
      end
    end

    def apply
    end

    protected

    def klass
      Template
    end

    private

    def sample_template
      Template.new(community: current_community)
    end

    def member_type_options
      People::MemberType.in_community(current_community)
    end

    # Pundit built-in helper doesn't work due to namespacing
    def template_params
      params.require(:billing_template).permit(policy(@template).permitted_attributes)
    end
  end
end
