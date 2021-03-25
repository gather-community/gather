# frozen_string_literal: true

module Calendars
  class NodesController < ApplicationController
    def move
      @node = Node.find(params[:id])
      authorize(@node)
      delta = case params[:dir]
              when "up" then -1
              when "down" then 1
              else 0
              end
      @node.update!(rank: @node.rank + delta)
      redirect_to(calendars_path)
    end
  end
end
