# frozen_string_literal: true

module GDrive
  class ItemGroupsController < ApplicationController
    include Destructible

    before_action -> { nav_context(:wiki, :gdrive) }

    def new
      @item_group = ItemGroup.new(item: Item.find(params[:item_id]))
      authorize(@item_group)
      prep_form_vars
    end

    def create
      item = Item.find(params[:gdrive_item_group][:item_id])
      @item_group = ItemGroup.new(item: item)

      authorize(@item_group)

      @item_group.assign_attributes(item_group_params)

      if @item_group.save
        flash[:success] = t("gdrive.group_added")
        redirect_to(gdrive_config_path)
      else
        prep_form_vars
        render(:new)
      end
    end

    def destroy
      simple_action(:destroy, redirect: gdrive_config_path)
    end

    protected

    def klass
      GDrive::ItemGroup
    end

    private

    def prep_form_vars
      @item = @item_group.item
      @access_levels = ItemGroup::ACCESS_LEVELS

      # We don't exclude hidden groups because they are useful here and only
      # admins can see this page. We do exclude groups that already have access to the item.
      @groups = Groups::Group.in_communities([current_community])
        .where.not(id: ItemGroup.where(item: @item).select(:group_id)).by_name
    end

    # Pundit built-in helper doesn't work due to namespacing
    def item_group_params
      params.require(:gdrive_item_group).permit(policy(@item_group).permitted_attributes)
    end
  end
end
