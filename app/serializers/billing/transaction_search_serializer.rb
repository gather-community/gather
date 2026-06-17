# frozen_string_literal: true

module Billing
  # Serializes Transactions for Elasticsearch.
  class TransactionSearchSerializer < ApplicationSerializer
    attributes :id, :kind, :community_id, :account_id, :statement_id, :description, :code

    def kind = "transaction"

    def community_id = object.account.community_id

    def description = object.description.to_s

    def code = object.code.to_s
  end
end
