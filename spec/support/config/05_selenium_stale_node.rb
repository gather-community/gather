# frozen_string_literal: true

# When a page navigates while Capybara is reading from it (e.g. `have_content` straight after a
# form submit), Chrome (seen on 154) sometimes reports the old document's nodes as
#   unhandled inspector error: ... "Node with given id does not belong to the document"
# instead of a stale element reference. It's the same condition, but Capybara only retries errors
# in `driver.invalid_element_errors` (by class), so this one escaped its synchronize loop and
# failed the spec outright. Translating it lets Capybara re-query against the new page.
module SeleniumStaleNodeTranslation
  STALE_NODE_MESSAGE = "Node with given id does not belong to the document"

  private

  def execute(...)
    super
  rescue Selenium::WebDriver::Error::UnknownError => e
    raise unless e.message.include?(STALE_NODE_MESSAGE)
    raise Selenium::WebDriver::Error::StaleElementReferenceError, e.message
  end
end

Selenium::WebDriver::Remote::Bridge.prepend(SeleniumStaleNodeTranslation)
