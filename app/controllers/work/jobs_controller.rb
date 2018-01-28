module Work
  class JobsController < ApplicationController
    before_action -> { nav_context(:work, :jobs) }

    decorates_assigned :job

    def new
      prep_form_vars
      @job = Job.new(community: current_community, period: @period)
      authorize @job
    end

    def edit
      @job = Job.find(params[:id])
      authorize @job
      prep_form_vars
    end

    def create
      @job = Job.new(community: current_community)
      @job.assign_attributes(job_params)
      authorize @job
      if @job.save
        flash[:success] = "Job created successfully."
        redirect_to work_jobs_path
      else
        set_validation_error_notice(@job)
        prep_form_vars
        render :new
      end
    end

    def update
      @job = Job.find(params[:id])
      authorize @job
      if @job.update_attributes(job_params)
        flash[:success] = "Job updated successfully."
        redirect_to work_jobs_path
      else
        set_validation_error_notice(@job)
        prep_form_vars
        render :edit
      end
    end

    private

    def sample_job
      Job.new(community: current_community)
    end

    def prep_form_vars
      @periods = Period.for_community(current_community).active
      @period = @periods.first # This will change to use lens.
      @requesters = People::Group.for_community(current_community).by_name
    end

    # Pundit built-in helper doesn't work due to namespacing
    def job_params
      params.require(:work_job).permit(policy(@job).permitted_attributes)
    end
  end
end
