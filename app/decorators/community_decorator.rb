# frozen_string_literal: true

class CommunityDecorator < ApplicationDecorator
  delegate_all

  def admin_action_link_set
    ActionLinkSet.new(
      ActionLink.new(object, :visit, icon: "external-link", path: h.url_in_community(object),
                                     permitted: true, html: {target: "_blank", rel: "noopener"}),
      ActionLink.new(object, :destroy, icon: "trash", path: h.community_path(object),
                                       method: :delete, btn_class: :danger,
                                       data: {
                                         controller: "community-delete",
                                         community_delete_slug_value: object.slug,
                                         action: "click->community-delete#confirm"
                                       })
    )
  end

  def country_name
    country = ISO3166::Country[object.country_code]
    country&.translations[I18n.locale.to_s] || country&.name || object.country_code
  end
end
