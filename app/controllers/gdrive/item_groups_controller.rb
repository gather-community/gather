# frozen_string_literal: true

module GDrive
  class ItemGroupsController < ApplicationController
    include Destructible

    before_action -> { nav_context(:wiki, :gdrive) }

    def new
      @item = Item.find(params[:item_id])
      @item_group = ItemGroup.new(item: @item)
      @access_levels = ItemGroup.access_levels_for_kind(@item.kind)

      # We don't exclude hidden groups because they are useful here and only
      # admins can see this page.
      @groups = Groups::Group.in_communities([current_community]).order(:name)

      authorize(@item_group)
    end

    def create
      item = Item.find(params[:gdrive_item_group][:item_id])
      @item_group = ItemGroup.new(item: item)

      authorize(@item_group)

      @item_group.assign_attributes(item_group_params)

      if @item_group.save
        flash[:success] = "Group added successfully."
        redirect_to(gdrive_items_path)
      else
        render(:new)
      end
    end

    def destroy
      simple_action(:destroy, redirect: gdrive_items_path)
    end

    protected

    def klass
      GDrive::ItemGroup
    end

    private

    # Pundit built-in helper doesn't work due to namespacing
    def item_group_params
      params.require(:gdrive_item_group).permit(policy(@item_group).permitted_attributes)
    end
  end
end
