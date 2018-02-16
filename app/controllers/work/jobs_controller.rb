module Work
  class JobsController < ApplicationController
    include Destructible

    before_action -> { nav_context(:work, :jobs) }
    decorates_assigned :job, :jobs
    helper_method :sample_job

    def index
      authorize sample_job
      @periods = Period.for_community(current_community).latest_first
      prepare_lenses("work/period": {periods: @periods, required: true, default: @periods.first.try(:id)})
      @period = Period.find(lenses[:period].value)
      @jobs = policy_scope(Job).for_community(current_community).
        in_period(@period).includes(:shifts).by_title
    end

    def new
      return render_not_found unless params[:period].present?
      @job = Job.new(community: current_community, period_id: params[:period])
      @job.shifts.build
      authorize @job
      prep_form_vars
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

    protected

    def klass
      Job
    end

    private

    def sample_job
      Job.new(community: current_community)
    end

    def prep_form_vars
      @requesters = People::Group.for_community(current_community).by_name
    end

    # Pundit built-in helper doesn't work due to namespacing
    def job_params
      params.require(:work_job).permit(policy(@job).permitted_attributes)
    end
  end
end
