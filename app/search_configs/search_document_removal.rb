# frozen_string_literal: true

# Removes a record's search document when the record is destroyed.
#
# A document that is already gone counts as removed. That happens whenever a record was deactivated
# before being destroyed, because deactivating removes the document too. Raising there would roll back
# the whole destroy, and with it any cascade it is part of, such as deleting a community.
module SearchDocumentRemoval
  extend ActiveSupport::Concern

  included do
    after_destroy :remove_search_document
  end

  def remove_search_document
    __elasticsearch__.delete_document
  rescue Elasticsearch::Transport::Transport::Errors::NotFound
    nil
  end
end
