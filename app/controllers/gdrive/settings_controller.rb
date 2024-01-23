# frozen_string_literal: true

module GDrive
  class SettingsController < ApplicationController
    before_action -> { nav_context(:wiki, :gdrive) }

    def show
      authorize(current_community, :setup?, policy_class: SetupPolicy)
      @config = MainConfig.find_by!(community: current_community)
      @items_by_kind = {}
      @items_by_kind[:drive] = []
      @items_by_kind[:folder] = []
      @items_by_kind[:file] = []
      @config.items.includes(:item_groups).order(:name).each do |item|
        @items_by_kind[item.kind.to_sym] << item
      end
    end
  end
end
