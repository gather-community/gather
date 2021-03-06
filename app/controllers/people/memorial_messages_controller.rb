# frozen_string_literal: true

module People
  class MemorialMessagesController < ApplicationController
    include Destructible

    def edit
      memorial = Memorial.find(params[:memorial_id])
      @memorial_message = memorial.messages.find(params[:id])
      authorize(@memorial_message)
    end

    def create
      memorial = Memorial.find(params[:memorial_id])
      @memorial_message = memorial.messages.new
      @memorial_message.assign_attributes(memorial_message_params.merge(author: current_user))
      authorize(@memorial_message)
      @memorial_message.save!
      flash[:success] = "Thanks for your message."
      redirect_to(@memorial_message.memorial)
    end

    def update
      @memorial_message = MemorialMessage.find(params[:id])
      authorize(@memorial_message)
      if params[:cancel]
        redirect_to(@memorial_message.memorial)
      elsif @memorial_message.update(memorial_message_params)
        flash[:success] = "Message updated successfully."
        redirect_to(@memorial_message.memorial)
      else
        render(:edit)
      end
    end

    def destroy
      @memorial = Memorial.find(params[:memorial_id])
      simple_action(:destroy, redirect: @memorial)
    end

    protected

    def klass
      MemorialMessage
    end

    private

    # Pundit built-in helper doesn't work due to namespacing
    def memorial_message_params
      params.require(:people_memorial_message).permit(policy(@memorial_message).permitted_attributes)
    end
  end
end
