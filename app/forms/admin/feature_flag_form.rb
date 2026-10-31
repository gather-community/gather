# frozen_string_literal: true

module Admin
  # Form for creating and editing a feature flag from the operator dashboard, including its selected
  # users. Users are only kept while the flag is on for selected users: saving it as off or on for
  # everyone deletes them, so a flag never carries a list that isn't in effect.
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

    def initialize(flag: nil, params: nil, permitted: Admin::FeatureFlagPolicy.permitted_attributes)
      @flag = flag || FeatureFlag.new(mode: :off)
      @user_ids = @flag.feature_flag_users.map(&:user_id)
      return if params.blank?
      params = ActionController::Parameters.new(params) unless params.is_a?(ActionController::Parameters)
      # Assign through our own writers so the name gets normalized.
      params.permit(permitted).each { |attr, value| send(:"#{attr}=", value) }
    end

    # IDs arrive as strings from the form, with a blank entry that lets an emptied list still be sent.
    def user_ids=(ids)
      @user_ids = Array.wrap(ids).compact_blank.map(&:to_i).uniq
    end

    # The selected users, for display. Users can be in any cluster.
    def users
      User.where(id: @user_ids).including_communities.by_name.decorate
    end

    def save
      return false unless valid?
      FeatureFlag.transaction do
        @flag.save!
        sync_users
      end
      true
    end

    private

    def sync_users
      keep_ids = (mode == :selected_users) ? User.where(id: @user_ids).pluck(:id) : []
      @flag.feature_flag_users.where.not(user_id: keep_ids).destroy_all
      (keep_ids - @flag.feature_flag_users.pluck(:user_id)).each do |user_id|
        @flag.feature_flag_users.create!(user_id: user_id)
      end
    end

    def name_unique
      return if name.blank? || FeatureFlag.where(name: name).where.not(id: @flag.id).none?
      errors.add(:name, :taken)
    end
  end
end
