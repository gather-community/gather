# frozen_string_literal: true

module Admin
  # Form for creating a feature flag from the operator dashboard.
  class FeatureFlagForm
    include ActiveModel::Conversion
    include ActiveModel::Validations
    include ActiveModel::Validations::Callbacks
    extend AttributeNormalizer::ClassMethods

    # Flag names are referenced from code (FeatureFlag.lookup("messaging")), so they look like
    # identifiers.
    NAME_FORMAT = /\A[a-z][a-z0-9_]*\z/

    delegate :name, :name=, :mode, :mode=, :persisted?, :new_record?, :id, :to_param, to: :@flag

    attr_reader :flag

    def self.model_name
      FeatureFlag.model_name
    end

    delegate :model_name, to: :class

    normalize_attributes :name, with: %i[strip blank downcase]

    validates :name, presence: true
    validates :name, length: {maximum: FeatureFlag::NAME_MAX_LENGTH}, format: {with: NAME_FORMAT},
      allow_blank: true
    validate :name_unique

    def initialize(flag: nil, params: nil)
      @flag = flag || FeatureFlag.new(mode: :off)
      return if params.blank?
      params = ActionController::Parameters.new(params) unless params.is_a?(ActionController::Parameters)
      # Assign through our own writers so the name gets normalized.
      params.permit(Admin::FeatureFlagPolicy.permitted_attributes).each { |attr, value| send(:"#{attr}=", value) }
    end

    def save
      return false unless valid?
      @flag.save!
    end

    private

    def name_unique
      return if name.blank? || FeatureFlag.where(name: name).where.not(id: @flag.id).none?
      errors.add(:name, :taken)
    end
  end
end
