class MealsController < ApplicationController
  load_and_authorize_resource

  def index
    @meals = Meal.today_or_future.oldest_first
  end

  def new
    @meal = Meal.new_with_defaults
    @min_date = Date.today.strftime("%Y-%m-%d")
    prep_form_vars
  end

  def edit
    @meal = Meal.find(params[:id])
    @min_date = nil
    prep_form_vars
  end

  def create
    if @meal.save
      flash[:success] = "Meal created successfully."
      redirect_to meals_path
    else
      set_validation_error_notice
      prep_form_vars
      render :new
    end
  end

  def update
    if @meal.update_attributes(meal_params)
      flash[:success] = "Meal updated successfully."
      redirect_to meals_path
    else
      set_validation_error_notice
      prep_form_vars
      render :edit
    end
  end

  private

  def prep_form_vars
    @meal.ensure_assignments
    @active_users = User.by_name.active
    @communities = Community.by_name
  end

  def meal_params
    permitted = [:title, :capacity, :entrees, :side, :kids, :dessert, :notes, :allergen_gluten,
      :allergen_shellfish, :allergen_soy, :allergen_corn, :allergen_dairy, :allergen_eggs,
      :allergen_peanuts, :allergen_almonds, :allergen_none,
      { :community_boxes => [Community.all.map(&:id).map(&:to_s)] }
    ]

    if can?(:manage, Meal)
      permitted += [:served_at, :location_id, {
        :head_cook_assign_attributes => [:id, :user_id],
        :asst_cook_assigns_attributes => [:id, :user_id, :_destroy],
        :cleaner_assigns_attributes => [:id, :user_id, :_destroy]
      }]
    end

    params.require(:meal).permit(*permitted)
  end
end
