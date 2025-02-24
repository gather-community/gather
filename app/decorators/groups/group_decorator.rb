# frozen_string_literal: true

module Groups
  class GroupDecorator < ApplicationDecorator
    delegate_all

    def name_with_suffix
      suffixes = []
      suffixes << t("common.inactive") if inactive?
      suffixes << t("common.hidden") if hidden?
      suffixes = suffixes.empty? ? "" : " (#{suffixes.join(', ')})"
      "#{name}#{suffixes}"
    end

    def name_with_inactive
      "#{name}#{active? ? '' : ' (Inactive)'}"
    end

    def tr_classes
      [active? ? nil : "inactive", hidden? ? "muted" : nil].compact.join(" ")
    end

    def availability_hint
      cmtys = single_community? ? "single_community" : "multi_community"
      I18n.t("groups.availability_hints.#{cmtys}.#{availability}")
    end

    def user_list(which_users, show_none: true)
      users = case which_users
              when :manager then managers
              when :member then members
              when :opt_out then opt_outs
              end
      return show_none ? "[#{t('common.none')}]" : "" if users.empty?

      items = h.safe_join(users.map { |u| h.tag.li(u.decorate.link(show_cmty_if_foreign: :abbrv)) })
      h.tag.ul(items, class: "no-bullets user-list-#{which_users.to_s.dasherize}")
    end

    def show_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :join, icon: "user-plus", path: h.join_groups_group_path(object),
                                      method: :put, label_symbol: everybody? ? :rejoin : :join),
        ActionLink.new(object, :leave, icon: "user-times", path: h.leave_groups_group_path(object),
                                       method: :put, label_symbol: everybody? ? :opt_out : :leave),
        ActionLink.new(object, :edit, icon: "pencil", path: h.edit_groups_group_path(object))
      )
    end

    def edit_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :deactivate, icon: "times-circle", method: :put, confirm: {name: name},
                                            path: h.deactivate_groups_group_path(object)),
        ActionLink.new(object, :destroy, icon: "trash", method: :delete, confirm: {name: name},
                                         path: h.groups_group_path(object))
      )
    end
  end
end
