module Meals
  class MessagesController < ApplicationController
    before_action -> { nav_context(:meals, :meals) }

    def new
      raise "invalid recipient type" unless Message::RECIPIENT_TYPES.include?(params[:r])
      @meal = Meal.find(params[:meal_id])
      @message = Message.new(meal: @meal, recipient_type: params[:r])
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
      params.require(:meals_message).permit(:body, :recipient_type)
    end
  end
end
