module Meals
  class MessagesController < ApplicationController
    before_action -> { nav_context(:meals, :meals) }

    def new
      @meal = Meal.find(params[:meal_id])
      @message = Message.new(meal: @meal)
      if params[:cancel]
        @message.kind = "cancellation"
        @message.recipient_type = "all"
      end
      show_cancel_notice
      authorize @message
    end

    def create
      @meal = Meal.find(params[:meal_id])
      @message = Message.new(meal: @meal, sender: current_user)
      @message.assign_attributes(message_params)
      authorize @message
      if @message.save
        @meal.cancel! if @message.cancellation?
        flash[:success] = "Message sent successfully."
        Delayed::Job.enqueue(MessageJob.new(@message.id))
        redirect_to meal_path(@meal)
      else
        show_cancel_notice
        set_validation_error_notice
        render :new
      end
    end

    private

    def show_cancel_notice
      flash.now[:alert] = I18n.t("meals/messages.cancel_notice")
    end

    def message_params
      params.require(:meals_message).permit(policy(@message).permitted_attributes)
    end
  end
end
