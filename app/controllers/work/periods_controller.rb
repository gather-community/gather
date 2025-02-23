# frozen_string_literal: true

module Work
  # Controls CRUD for periods, plus the work report.
  class PeriodsController < WorkController
    include Destructible

    before_action -> { nav_context(:work, :periods) }, except: :report
    before_action -> { nav_context(:work, :report) }, only: :report

    decorates_assigned :period, :periods

    # decorates_assigned :report collides with action method
    helper_method :work_report

    def index
      authorize(sample_period)
      @periods = policy_scope(Period).in_community(current_community).newest_first.page(params[:page])
    end

    def new
      @period = Period.new_with_defaults(current_community)
      if params[:clone_from]
        old_period = Period.find(params[:clone_from])
        cloner = PeriodCloner.new(old_period: old_period, new_period: @period)
        cloner.copy_attributes_and_shares
        flash.now[:notice] = "Some data have been copied from the period '#{old_period.name}'. " \
                             "Please review and adjust below. Jobs will be copied when you save the period."
      end
      authorize(@period)
      @periods = Period.in_community(current_community).newest_first
      prep_form_vars
    end

    def show
      @period = Period.find(params[:id])
      authorize(@period)
      prep_form_vars
    end

    def edit
      @period = Period.find(params[:id])
      authorize(@period)
      prep_form_vars
      flash.now[:alert] = t("work/shares.change_warning") unless period.draft? || period.archived?
    end

    def create
      @period = Period.new(community: current_community)
      @period.assign_attributes(period_params)
      authorize(@period)
      if @period.valid?
        if @period.job_copy_source_id.present?
          copy_jobs_and_redirect
        else
          @period.save!
          calculate_quota_and_redirect
        end
      else
        prep_form_vars
        render(:new)
      end
    end

    def update
      @period = Period.find(params[:id])
      authorize(@period)
      if @period.update(period_params)
        QuotaCalculator.new(@period).recalculate_and_save
        flash[:success] = "Period updated successfully."
        redirect_to(work_periods_path)
      else
        prep_form_vars
        render(:edit)
      end
    end

    def report
      prepare_lenses(:"work/period")
      @period = lenses[:period].selection
      if @period.nil?
        authorize(sample_period, :report_wrapper?)
        lenses.hide!
      else
        authorize(@period, :report_wrapper?)
        @work_report = Report.new(period: @period, user: current_user) if policy(@period).report?
      end
    end

    def review_notices
      @period = Period.find(params[:id])
      authorize(@period)
      if !(@period.ready? || @period.open?)
        @error = "Notices can't be sent because the period is not in the 'ready' or 'open' phase."
      elsif @period.quota_none?
        @error = "Notices can't be sent because this period doesn't have a quota."
      else
        @notices = Work::Share.for_period(period).nonzero.by_user_name.map do |share|
          # .body was sometimes returning an empty String object.
          body = WorkMailer.job_choosing_notice(share).body
          body.is_a?(Mail::Body) ? body.encoded : body
        end
      end
    end

    def send_notices
      @period = Period.find(params[:id])
      authorize(@period)
      JobChoosingNoticeJob.perform_later(@period.id)
      flash[:success] = "Notices are on the way!"
      redirect_to(work_period_path(@period))
    end

    protected

    def klass
      Period
    end

    private

    def work_report
      @work_report_decorated ||= ReportDecorator.new(@work_report)
    end

    def prep_form_vars
      @share_builder = PeriodShareBuilder.new(@period)
      @share_builder.build
      @users_by_life_stage = UserDecorator.decorate_collection(@share_builder.users).group_by(&:life_stage)
      @shares_by_user = @period.shares.index_by(&:user_id)
      @meal_job_sync_settings = MealJobSyncSettingCollection.new(period: period)
    end

    def copy_jobs_and_redirect
      old_period = Period.find(@period.job_copy_source_id)
      PeriodCloner.new(old_period: old_period, new_period: @period).copy_jobs
      # This shouldn't error. If it does, PeriodCloner should have written some debug info.
      @period.save!
      calculate_quota_and_redirect
    end

    def calculate_quota_and_redirect
      QuotaCalculator.new(@period).recalculate_and_save
      flash[:success] = "Period created successfully."
      redirect_to(work_periods_path)
    end

    # Pundit built-in helper doesn't work due to namespacing
    def period_params
      params.require(:work_period).permit(policy(@period).permitted_attributes)
    end
  end
end
