# frozen_string_literal: true

module Work
  # Controls CRUD for the work view of job templates. There is a separate controller for the meals view.
  class JobTemplatesController < WorkController
    include Destructible

    before_action -> { nav_context(:work, :job_templates) }

    decorates_assigned :template, :templates
    helper_method :sample_template

    def index
      authorize(sample_template)
      @templates = policy_scope(JobTemplate).in_community(current_community).by_title
    end

    def new
      @template = JobTemplate.new
      authorize(@template)
      prep_form_vars
    end

    def edit
      @template = JobTemplate.find(params[:id])
      authorize(@template)
      prep_form_vars
    end

    def create
      @template = JobTemplate.new(job_template_params.merge(community_id: current_community))
      authorize(@template)
      if @template.save
        flash[:success] = "Template created successfully."
        redirect_to(work_job_templates_path)
      else
        prep_form_vars
        render(:new)
      end
    end

    def update
      @template = JobTemplate.find(params[:id])
      authorize(@template)
      if @template.update(job_template_params)
        flash[:success] = "Template updated successfully."
        redirect_to(work_job_templates_path)
      else
        prep_form_vars
        render(:edit)
      end
    end

    protected

    def klass
      JobTemplate
    end

    private

    def prep_form_vars
      @requesters = People::Group.in_community(current_community).by_name
    end

    def sample_template
      JobTemplate.new(community: current_community)
    end

    # Pundit built-in helper doesn't work due to namespacing
    def job_template_params
      # params.require(:work_period).permit(policy(@period).permitted_attributes)
    end
  end
end
