# frozen_string_literal: true

# Prepares search indices by setting up a separate search index
# (so as not to mess up the ones used by the dev environment).
# The create action will delete and re-create the index if it already exists.
RSpec.configure do |config|
  config.before(search: true) do |example|
    Array.wrap(example.metadata[:search]).each do |m|
      m.__elasticsearch__.index_name = "#{m.model_name.param_key}_test"
      m.__elasticsearch__.create_index!(force: true)
    end
  end
end
