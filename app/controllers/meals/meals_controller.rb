# frozen_string_literal: true

module Meals
  class MealsController < ApplicationController
    include ExpenseFormable
    include Lensable
    include HouseholdSignupFormable
    include Destructible

    decorates_assigned :meal, :meals, :meal_summary, :report, :user, :signup, :signups, :cost, :formula

    # decorates_assigned :report collides with action method
    helper_method :meals_report

    before_action -> { nav_context(:meals, :meals) }, except: %i[jobs report]

    def index
      prepare_lenses(:search, :"meals/time", :community)

      authorize(sample_meal)
      load_meals(:index)
      load_communities_in_cluster
    end

    def jobs
      authorize(sample_meal)
      nav_context(:meals, :jobs)
      prepare_lenses(:"meals/job_user", :"meals/time")
      @user = lenses[:user].user
      load_meals(:jobs)
      load_communities_in_cluster
    end

    def show
      @meal = Meal.find(params[:id])
      authorize(@meal)

      # Don't want the signup form to get cached
      set_no_cache unless @meal.in_past?

      flash.now[:error] = I18n.t("meals.cancelled_notice") if @meal.cancelled?

      @signup = Signup.for(current_user, @meal)
      @signup_parts = @signup.parts
      @expand_signup_form = params[:signup].present? || @signup.persisted?
      prep_show_meal_vars
    end

    def report
      authorize(sample_meal, :report?)
      @community = current_community
      nav_context(:meals, :report)
      prepare_lenses(*report_lenses)
      @meals_report = Report.new(@community, range: lenses[:dates].range)
      @communities = Community.by_name_with_first(@community).to_a
    end

    def new
      @meal = init_meal
      authorize(@meal)
      prep_form_vars
    end

    def edit
      @meal = Meal.find(params[:id])
      authorize(@meal)
      ensure_blank_assignments_present
      prep_form_vars
    end

    def create
      @meal = Meal.new(
        community_id: current_user.community_id,
        community_ids: [current_user.community_id],
        creator: current_user
      )
      @meal.assign_attributes(meal_params)
      @meal.build_events
      authorize(@meal)
      if @meal.save
        flash[:success] = "Meal created successfully."
        redirect_to(meals_path)
      else
        prep_form_vars
        render(:new)
      end
    end

    def update
      @meal = Meal.find(params[:id])
      authorize(@meal)
      @worker_change_notifier = WorkerChangeNotifier.new(current_user, @meal)
      @meal.assign_attributes(meal_params)
      @meal.build_events
      if @meal.save
        flash[:success] = "Meal updated successfully."
        @worker_change_notifier.check_and_send!
        redirect_to(meals_path)
      else
        prep_form_vars
        render(:edit)
      end
    end

    def close
      @meal = Meal.find(params[:id])
      authorize(@meal)
      @meal.close!
      flash[:success] = "Meal closed successfully."
      redirect_to(meals_path)
    end

    def reopen
      @meal = Meal.find(params[:id])
      authorize(@meal)
      if @meal.auto_close_time_in_past?
        flash[:error] = "You can't reopen this meal because its auto-close time is in the past. " \
                        "Please change or remove the auto-close time before proceeding."
        redirect_to(meal_path(@meal))
      else
        @meal.reopen!
        flash[:success] = "Meal reopened successfully."
        redirect_to(meals_path)
      end
    end

    def unfinalize
      @meal = Meal.find(params[:id])
      authorize(@meal)
      Finalizer.new(@meal).unfinalize!
      flash[:success] = "Meal unfinalized successfully."
      redirect_to(meal_path(@meal))
    end

    def summary
      @meal = Meal.find(params[:id]).decorate
      @meal_summary = Summary.new(@meal)
      @portion_count_builder = PortionCountBuilder.new(@meal)
      authorize(@meal)
      load_signups
      @cost_calculator = CostCalculator.build(@meal)
      return unless @meal.open? && current_user == @meal.head_cook

      flash.now[:alert] = "Note: This meal is not yet closed and people can still sign up for it. " \
                          "You should close the meal before printing this summary."
    end

    # Renders just the workers section of the form. Accepts a formula_id, and sets the
    # meal formula to that ID (without saving) if provided.
    # This is a collection action, only used for new meals.
    def worker_form
      @meal = init_meal(formula_id: params[:formula_id])
      authorize(@meal, :new?)
      prep_worker_form_vars
      render(partial: "meals/meals/form/single_section", layout: false, locals: {section: "workers"})
    end

    def reimbursee_paypal_email
      user = User.find(params[:user_id])
      authorize(user, :show?)
      render(json: {email: user.paypal_email_or_default})
    end

    protected

    def klass
      Meal
    end

    def meals_report
      @meals_report_decorated ||= ReportDecorator.new(@meals_report)
    end

    def default_url_options
      {mode: params[:mode]}
    end

    # See def'n in ApplicationController for documentation.
    def community_for_route
      case params[:action]
      when "show", "summary"
        Meal.find_by(id: params[:id]).try(:community)
      when "index", "jobs", "report", "reports"
        current_user.community
      end
    end

    private

    # Pundit built-in helper doesn't work due to namespacing
    def meal_params
      permitted = policy(@meal).permitted_attributes
      params.require(:meals_meal).permit(permitted).tap do |permitted|
        # If no allergen boxes are checked, this param won't exist at all, so old value won't get overwritten
        # We check if no_allergens is permitted to see if the user can edit allergen info. Otherwise,
        # if we add this field it causes weird errors.
        permitted["allergens"] ||= [] if permitted.include?(:no_allergens)
      end
    end

    def init_meal(formula_id: nil)
      community = current_community
      formula = formula_id.nil? ? Formula.default_for(community) : Formula.find(formula_id)
      served_at = Time.current.midnight + 7.days + Meal::DEFAULT_TIME
      invite_all_communities = current_community.settings.meals.default_invites == "all"
      meal = Meal.new(
        served_at: served_at,
        capacity: community.settings.meals.default_capacity,
        community_ids: invite_all_communities ? Community.all.map(&:id) : [community.id],
        community: community,
        formula: formula
      )
      (formula&.roles || []).each do |role|
        role.count_per_meal.times { meal.assignments.build(role: role) }
      end
      meal
    end

    def load_meals(context)
      @meals = policy_scope(Meal)
      @meals = @meals.hosted_by(context == :index ? lenses[:community].selection : current_community)
      @meals = @meals.worked_by(lenses[:user].value) if lenses[:user].present?

      @meals = if lenses[:time].finalizable?
                 @meals.finalizable.where(community_id: current_community).oldest_first
               elsif lenses[:time].past?
                 @meals.past.newest_first
               elsif lenses[:time].all?
                 @meals.oldest_first
               else
                 @meals.future.oldest_first
               end
      @meals = @meals.includes(:calendars, :invitations, assignments: %i[role user],
                                                         signups: {parts: :type})

      if params[:search].present?
        subq = Assignment.select("DISTINCT meal_id").joins(:user)
          .where("first_name ILIKE ? OR last_name ILIKE ?", "%#{params[:search]}%", "%#{params[:search]}%")
          .where("meals.id = meal_assignments.meal_id")
        @meals = @meals.where("title ILIKE ? OR meals.id IN (#{subq.to_sql})", "%#{params[:search]}%")
      end

      @meals = @meals.page(params[:page])
    end

    def prep_show_meal_vars
      load_signups
      prep_signup_form_vars
      @cost = @meal.cost || @meal.build_cost
      @formula = @meal.formula
      @calculator = Meals::CostCalculator.build(@meal)
      @household_workers = Meals::HouseholdWorkersPresenter.new(@meal, current_user.household)
    end

    def prep_form_vars
      prep_worker_form_vars
      prep_expense_form_vars
      load_communities_in_cluster
      @formula_options = policy_scope(Formula).in_community(current_community)
        .active_or_selected(@meal.formula_id).by_name
      @calendar_options = policy_scope(Calendars::Calendar).active.meal_hostable.by_cmty_and_name.decorate
      @sample_formula = Formula.new(community: current_community)
      @sample_calendar = Calendars::Calendar.new(community: current_community)
    end

    def prep_worker_form_vars
      @roles = (meal.roles + meal.assignments.map(&:role)).uniq
    end

    def load_signups
      @signups = @meal.signups.by_one_cmty_first(@meal.community).sorted
        .includes(parts: :type, household: :community)
    end

    def sample_meal
      Meals::Meal.new(community: current_community)
    end

    def ensure_blank_assignments_present
      meal.roles.each do |role|
        current_count = @meal.assignments.count { |a| a.role == role }
        [0, role.count_per_meal - current_count].max.times do
          @meal.assignments.build(role: role)
        end
      end
    end

    def report_lenses
      first_meal_date = Meal.minimum(:served_at)&.to_date
      result = []
      result << {date_range: {min_date: first_meal_date}}
      result << {community: {clearable: false}} if multi_community?
      result
    end
  end
end
