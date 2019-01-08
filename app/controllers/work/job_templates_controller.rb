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

    protected

    def klass
      JobTemplate
    end

    private

    def sample_template
      JobTemplate.new(community: current_community)
    end

    # Pundit built-in helper doesn't work due to namespacing
    def job_template_params
      # params.require(:work_period).permit(policy(@period).permitted_attributes)
    end
  end
end
