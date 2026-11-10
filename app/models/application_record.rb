# frozen_string_literal: true

# Parent class of all DB-backed models.
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  # Transient attribute used by factories to signal that we don't want a listener to do something.
  attr_accessor :skip_listener_action

  # Sorts text columns the way people expect in the current locale, rather than by the bytes of their
  # characters (which puts "Émile" after "Zoe"). See Gather::Collation.
  #
  # Takes one or more symbols or hashes (e.g. `alpha_order(:name, :title, communities: :name)`)
  # and converts to an `order` call that collates each column
  # (e.g. order('name COLLATE "sv-x-icu", title COLLATE "sv-x-icu", communities.name COLLATE "sv-x-icu"')).
  # If the value in a hash element is `:desc`, sorts descending.
  def self.alpha_order(*args)
    collate = "COLLATE #{Gather::Collation.quoted_name}"
    cols = args.flat_map do |arg|
      if arg.is_a?(Hash)
        arg.map { |k, v| (v == :desc) ? "#{k} #{collate} DESC" : "#{k}.#{v} #{collate}" }
      else
        "#{arg} #{collate}"
      end
    end
    order(Arel.sql(cols.join(", ")))
  end

  def self.test_mock?
    false
  end

  # This is added by ActsAsTenant
  def self.scoped_by_tenant?
    false
  end

  # ActsAsTenant checks that each belongs_to points to a record in the current cluster. Associations to
  # User are exempt because a super admin can act in a cluster other than their own, so the records
  # they create there (wiki pages, events, meals, messages) point to a user from another cluster.
  def validate_tenant_association?(reflection)
    reflection.polymorphic? || !(reflection.klass <= User)
  end

  protected

  # Runs the given block inside a transaction with repeatable_read isolation.
  # If ActiveRecord::SerializationFailure results, tries it repeatedly until it succeeds or
  # the maximum number of tries is reached, in which case it re-raises the
  # ActiveRecord::SerializationFailure error.
  def repeatable_read_transaction_with_retries(max_tries: 10)
    tries = 0
    loop do
      transaction(isolation: :repeatable_read) do
        yield
      end
      break
    rescue ActiveRecord::SerializationFailure => e
      tries += 1
      raise e if tries >= max_tries
    end
  end
end
