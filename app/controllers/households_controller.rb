class HouseholdsController < ApplicationController
  load_and_authorize_resource

  def index
    respond_to do |format|
      format.html do
        @households = @households.includes(:users).by_name.page(params[:page])
      end
      format.json do
        @households = @households.matching(params[:search])
        @households = @households.by_commty_and_name.page(params[:page]).per(20)
        render(json: @households, meta: { more: @households.next_page.present? })
      end
    end
  end

  def create
    if @household.save
      flash[:success] = "Household created successfully."
      redirect_to households_path
    else
      set_validation_error_notice
      render :new
    end
  end

  def update
    if @household.update_attributes(household_params)
      flash[:success] = "Household updated successfully."
      redirect_to households_path
    else
      set_validation_error_notice
      render :edit
    end
  end

  private

  def household_params
    params.require(:household).permit(:name, :community_id, :unit_num, :old_id, :old_name)
  end
end
