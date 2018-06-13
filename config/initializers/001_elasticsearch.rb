# frozen_string_literal: true

Elasticsearch::Model.client = Elasticsearch::Client.new(Settings.elasticsearch || {})
