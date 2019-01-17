class ApplicationDecorator < Draper::Decorator
  include Utilities

  delegate :t, to: :h # I18n helper

  def self.collection_decorator_class
    PaginatingDecorator
  end

  def cmty_prefix
    @cmty_prefix ||= multi_community? ? "#{community.abbrv}: " : ""
  end

  def cmty_prefix_no_colon
    @cmty_prefix_no_colon ||= multi_community? ? "#{community.abbrv} " : ""
  end

  def l(*args)
    return nil if args.first.nil?
    I18n.l(*args)
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

  def action_links(action = :show, **options)
    send("#{action}_action_link_set").render(**options)
  end

  def to_int_if_no_fractional_part(num)
    # Convert to integer if no fractional part so that .0 doesn't show.
    (num - num.to_i < 0.0001) ? num.to_i : num
  end

  def safe_str
    "".html_safe # rubocop:disable Rails/OutputSafety # It's just an empty string!
  end

  def join_icons(icons)
    icons.map { |i| safe_str << nbsp(2) << i }.reduce(&:<<)
  end
end
