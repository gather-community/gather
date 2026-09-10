# frozen_string_literal: true

require "csv"

# Base class for CSV exporters.
class CsvExporter
  attr_accessor :initial_scope, :policy

  def initialize(initial_scope, policy:)
    self.initial_scope = initial_scope
    self.policy = policy
  end

  def to_csv
    str = CSV.generate do |csv|
      csv << headers
      scope(initial_scope).each do |object|
        csv << row_for(object)
      end
    end

    # Fix Excel issue where file is interpreted as SYLK file by quoting first column header if it's ID
    str.sub(/\AID(?=(,|\z))/, %("ID"))
  end

  protected

  # Override to add to scope given to exporter, such as eager loads to improve efficiency.
  # By convention, it is the controller's responsibility to set sort order and include any joins
  # that are necessary for it.
  def scope(initial_scope)
    initial_scope
  end

  def klass
    raise NotImplementedError
  end

  def decorator_class
    raise NotImplementedError
  end

  private

  def columns
    @columns ||= policy.exportable_attributes
  end

  def headers
    columns.map { |c| header_for(c) }
  end

  # Overridable so subclasses can support column objects other than plain symbols.
  def header_for(column)
    I18n.t("csv.headers.#{klass.model_name.i18n_key}.#{column}")
  end

  def row_for(object)
    decorated = decorator_class.new(object)
    columns.map { |c| value_for(decorated, c) }
  end

  # Overridable, see header_for.
  def value_for(decorated, column)
    decorated.send(column)
  end
end
