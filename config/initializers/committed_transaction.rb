# frozen_string_literal: true

# Must be subscribed before any listener calls Gather::CommittedTransaction.once. See that module.
Rails.application.config.after_initialize do
  Gather::CommittedTransaction.subscribe
end
