# frozen_string_literal: true

module Nav
  # Builds the nav menus for the layout and renders their links.
  #
  # The items themselves come from a menu: AdminMenu on operator pages (see admin_mode?), otherwise
  # CommunityMenu. Each item is a hash with :name, :parents (for the i18n key), :path, :permitted and
  # optionally :icon, :display, :method and :i18n_key. This class drops the unpermitted ones and marks
  # the one matching the nav context as active.
  class Builder < ApplicationDecorator
    delegate_all

    attr_accessor :context, :current_period

    def initialize
      self.context = {}
    end

    def main_items(display:)
      filter_and_set_active_items(menu.main_items, display: display, active: context[0])
    end

    def sub_items(main_item = nil)
      filter_and_set_active_items(menu.sub_items(main_item || context[0]), active: context[1])
    end

    # This method has no arguments because it's only called once. It's not used to populate
    # the hamburger menu.
    def sub_sub_items
      return @sub_sub_items if defined?(@sub_sub_items)
      items = menu.sub_sub_items
      depth = Array.wrap(items&.first&.dig(:parents)).size
      @sub_sub_items = filter_and_set_active_items(items, active: context[depth])
    end

    def personal_items
      filter_and_set_active_items(menu.personal_items)
    end

    def label(item)
      return item[:name] if item[:name].is_a?(String)
      i18n_key_parts = ["nav_links"]
      i18n_key_parts.concat(Array.wrap(item[:parents]))
      i18n_key_parts << (item[:i18n_key] || item[:name])
      i18n_key = i18n_key_parts.join(".")
      t("#{i18n_key}._self", default: :"#{i18n_key}")
    end

    def link(item, tab: false, icon: true)
      name = label(item)
      params = {}
      params[:method] = item[:method]
      params[:role] = "tab" if tab
      params[:"aria-controls"] = name if tab
      icon_tag = if icon && item[:icon]
        icon_name = item[:icon].is_a?(Hash) ? item[:icon][:name] : item[:icon]
        icon_style = item[:icon].is_a?(Hash) ? item[:icon][:style] : nil
        h.icon_tag(icon_name, style: icon_style) << " "
      else
        h.safe_str
      end

      h.link_to(icon_tag << " #{name}", url(item[:path]), params)
    end

    private

    def menu
      @menu ||= h.admin_mode? ? AdminMenu.new(self) : CommunityMenu.new(self)
    end

    # We have to add the full host, port, and protocol if it's not given since some pages
    # are under the apex gather domain with community specified through query string but we want the
    # nav links to go back to the subdomain. Operator pages have no community and are all on the apex
    # domain, so their paths stay as they are.
    def url(path)
      return path if community.nil? || %r{\Ahttps?://}.match?(path)
      h.url_in_community(community, path)
    end

    def filter_and_set_active_items(items, display: nil, active: nil)
      return [] if items.blank?
      items = items.select { |i|
        i[:permitted] && (display.nil? || i[:display].nil? || i[:display] == display)
      }
      items.each do |i|
        i[:active] = true if active && i[:name] == active
      end
      items
    end

    def community
      h.current_community
    end
  end
end
