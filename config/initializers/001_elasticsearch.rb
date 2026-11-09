# frozen_string_literal: true

Elasticsearch::Model.client = Elasticsearch::Client.new(Settings.elasticsearch.to_h || {})

# Create indices on boot if they don't exist yet (idempotent).
# Rescuing here ensures an ES outage at startup doesn't crash the app.
Rails.application.config.after_initialize do
  [
    Work::Shift, Wiki::Page,
    Calendars::Event, Calendars::Calendar,
    Groups::Group,
    User, Household,
    Meals::Meal,
    People::Memorial, People::EmergencyContact, People::Pet, People::Vehicle,
    Billing::Transaction
  ].each do |model|
    begin
      model.__elasticsearch__.create_index!(force: false)
    rescue Elasticsearch::Transport::Transport::Errors::BadRequest => e
      # create_index! checks for the index and then creates it, so when two servers boot at once
      # (as in a deploy) both can try. The index existing is all we wanted.
      raise unless e.message.include?("resource_already_exists_exception")
    end
  rescue Faraday::Error, Elasticsearch::Transport::Transport::Error => e
    Sentry.capture_exception(e)
    Rails.logger.warn("Could not create ES index for #{model}: #{e.message}")
  end
end
