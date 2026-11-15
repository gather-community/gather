# frozen_string_literal: true

# Drives FullCalendar's (jQuery-UI-based) drag and resize with a real pointer. HTML5 drag_to doesn't
# work with FullCalendar, so these move the mouse directly, in steps, so the drag registers.
module CalendarDragHelpers
  # Drags an event down (or up, for a negative distance) by a number of pixels.
  def drag_vertically(element, by:)
    drag_by(element, x: 0, y: by)
  end

  # Drags an event across by a number of day columns (negative for earlier days).
  def drag_horizontally(element, columns:)
    drag_by(element, x: columns * day_column_width, y: 0)
  end

  # Drags an event onto another element, e.g. a day's cell in the all-day row.
  def drag_onto(element, target)
    page.driver.browser.action
      .move_to(element.native).pause(duration: 0.1)
      .click_and_hold.pause(duration: 0.1)
      .move_by(0, 10).pause(duration: 0.1)
      .move_to(target.native).pause(duration: 0.2)
      .release
      .perform
  end

  # Drags a timed event's bottom edge, where FullCalendar puts its resize handle (shown on hover).
  # Selenium offsets are from the element's center, so this aims a few pixels inside the edge.
  def resize_vertically(element, by:)
    bottom = (element.native.size.height / 2) - 3
    resize_from(element, x: 0, y: bottom, dx: 0, dy: by)
  end

  # Drags an all-day event's right edge across by a number of day columns.
  def resize_horizontally(element, columns:)
    right = (element.native.size.width / 2) - 3
    resize_from(element, x: right, y: 0, dx: columns * day_column_width, dy: 0)
  end

  def modal_button_labels
    with_top_level_scope { find("#{modal_selector} .modal-footer").all("button").map(&:text) }
  end

  # Polls the block until it returns truthy or the timeout elapses (the DB update lands asynchronously
  # after the XHR completes, so Capybara's own waiting doesn't cover it).
  def eventually(timeout: 5)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    loop do
      return true if yield
      return false if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      sleep(0.1)
    end
  end

  private

  def drag_by(element, x:, y:)
    steps = 4
    action = page.driver.browser.action
      .move_to(element.native).pause(duration: 0.1)
      .click_and_hold.pause(duration: 0.1)
    steps.times do |i|
      dx = (x * (i + 1) / steps) - (x * i / steps)
      dy = (y * (i + 1) / steps) - (y * i / steps)
      action = action.move_by(dx, dy).pause(duration: 0.1)
    end
    action.release.perform
  end

  def resize_from(element, x:, y:, dx:, dy:)
    page.driver.browser.action
      .move_to(element.native, x, y).pause(duration: 0.2)
      .click_and_hold.pause(duration: 0.1)
      .move_by(dx / 2, dy / 2).pause(duration: 0.1)
      .move_by(dx - (dx / 2), dy - (dy / 2)).pause(duration: 0.1)
      .release
      .perform
  end

  def day_column_width
    find(".fc-day-header", match: :first).native.size.width
  end
end
