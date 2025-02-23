# frozen_string_literal: true

class ApplicationDecorator < Draper::Decorator
  include MultiCommunityCheck

  delegate :t, :l, :safe_str, :safe_join, to: :h

  def self.collection_decorator_class
    PaginatingDecorator
  end

  def cmty_prefix
    @cmty_prefix ||= multi_community? ? "#{community.abbrv}: " : ""
  end

  def cmty_prefix_no_colon
    @cmty_prefix_no_colon ||= multi_community? ? "#{community.abbrv} " : ""
  end

  # Returns a Proc that inserts the given separator, to be passed to array.reduce.
  def sep(separator)
    ->(a, b) { a << separator.html_safe << b }
  end

  def nbsp(count = 1)
    ("&nbsp" * count).html_safe
  end

  def br
    h.tag(:br)
  end

  def action_links(action = :show, **)
    send("#{action}_action_link_set").render(**)
  end

  def to_int_if_no_fractional_part(num)
    # Convert to integer if no fractional part so that .0 doesn't show.
    num - num.to_i < 0.0001 ? num.to_i : num
  end

  def join_icons(icons)
    icons.map { |i| safe_str << nbsp(2) << i }.reduce(&:<<)
  end

  protected

  def decimal_to_percentage(num)
    h.number_to_percentage(num.try(:*, 100), precision: 1)
  end
end
