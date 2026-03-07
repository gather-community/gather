# frozen_string_literal: true

Elasticsearch::Model.client = Elasticsearch::Client.new(Settings.elasticsearch.to_h || {})

# Create indices on boot if they don't exist yet (idempotent).
# Rescuing here ensures an ES outage at startup doesn't crash the app.
Rails.application.config.after_initialize do
  [Work::Shift, Wiki::Page].each do |model|
    model.__elasticsearch__.create_index!(force: false)
  rescue Faraday::Error, Elasticsearch::Transport::Transport::Error => e
    Rails.logger.warn("Could not create ES index for #{model}: #{e.message}")
  end
end
