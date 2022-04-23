# frozen_string_literal: true

module Meals
  class MessagesController < ApplicationController
    before_action -> { nav_context(:meals, :meals) }

    decorates_assigned :meal

    def new
      @meal = Meal.find(params[:meal_id])
      @message = Message.new(meal: @meal)
      if params[:cancel]
        @message.kind = "cancellation"
        @message.recipient_type = "all"
      end
      show_cancel_notice_if_appropriate
      authorize(@message)
    end

    def create
      @meal = Meal.find(params[:meal_id])
      @message = Message.new(meal: @meal, sender: current_user)
      @message.assign_attributes(message_params)
      authorize(@message)
      if @message.save
        @meal.cancel! if @message.cancellation?
        flash[:success] = "Message sent successfully."
        MessageJob.perform_later(@message.id)
        redirect_to(meal_path(@meal))
      else
        show_cancel_notice_if_appropriate
        render(:new)
      end
    end

    private

    def show_cancel_notice_if_appropriate
      flash.now[:error] = I18n.t("meals/messages.cancel_notice_html") if @message.cancellation?
    end

    def message_params
      params.require(:meals_message).permit(policy(@message).permitted_attributes)
    end
  end
end
