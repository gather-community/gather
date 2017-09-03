module Meals
  class MessagesController < ApplicationController
    before_action -> { nav_context(:meals, :meals) }

    def new
      @meal = Meal.find(params[:meal_id])
      @message = Message.new(meal: @meal)
      authorize @message
    end

    def create
      @meal = Meal.find(params[:meal_id])
      @message = Message.new(meal: @meal, sender: current_user)
      @message.assign_attributes(message_params)
      authorize @message
      if @message.save
        Delayed::Job.enqueue(MessageJob.new(@message.id))
        flash[:success] = "Message sent successfully."
        redirect_to meal_path(@meal)
      else
        set_validation_error_notice
        render :new
      end
    end

    private

    def message_params
      params.require(:meals_message).permit(policy(@message).permitted_attributes)
    end
  end
end
