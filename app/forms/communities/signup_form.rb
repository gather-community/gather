# frozen_string_literal: true

module Communities
  class SignupForm
    include ActiveModel::Conversion
    include ActiveModel::Validations
    include ActiveModel::Validations::Callbacks
    extend AttributeNormalizer::ClassMethods

    delegate :contact_first_name, :contact_last_name, :contact_email,
      :community_name, :slug, :country_code, :time_zone,
      :introduction, :want_sample_data, :contact_name, to: :@signup

    delegate :contact_first_name=, :contact_last_name=, :contact_email=,
      :community_name=, :slug=, :introduction=, to: :@signup

    attr_reader :signup
    attr_accessor :hcaptcha_verified

    def self.model_name
      Communities::Signup.model_name
    end

    def model_name
      self.class.model_name
    end

    normalize_attributes :contact_first_name, :contact_last_name, :community_name, :introduction
    normalize_attributes :contact_email, with: :email
    normalize_attributes :slug, with: %i[strip blank downcase]

    validates :contact_first_name, :contact_last_name, :contact_email,
      :community_name, :slug, :country_code, :time_zone, :introduction, presence: true
    validates :contact_first_name, :contact_last_name,
      length: {maximum: Communities::Signup::CONTACT_NAME_MAX_LENGTH}, allow_blank: true
    validates :contact_email, length: {maximum: Communities::Signup::CONTACT_EMAIL_MAX_LENGTH},
      format: {with: Devise.email_regexp}, allow_blank: true
    validates :introduction, length: {maximum: Communities::Signup::INTRODUCTION_MAX_LENGTH}, allow_blank: true
    validates :community_name, length: {maximum: Communities::Signup::COMMUNITY_NAME_MAX_LENGTH},
      allow_blank: true
    validates :slug, length: {maximum: Communities::Signup::SLUG_MAX_LENGTH},
      format: {
        with: /\A[a-z][a-z0-9\-]*\z/,
        message: "only lowercase letters, numbers, and hyphens; must start with a letter"
      },
      allow_blank: true
    validate :slug_unique

    def initialize(action: nil, signup: nil, params: nil)
      @action = action
      @signup = signup || Communities::Signup.new(want_sample_data: true)

      if params.present?
        unless params.is_a?(ActionController::Parameters)
          params = ActionController::Parameters.new(params)
        end
        @signup.assign_attributes(params.permit(Communities::SignupPolicy.permitted_attributes))
      end
    end

    def save
      return false unless valid?
      @signup.save
    end

    private

    delegate :new_record?, :persisted?, :id, to: :@signup

    def slug_unique
      return if slug.blank?
      return if Communities::Signup.where(slug: slug).none? && Community.where(slug: slug).none?
      errors.add(:slug, "has already been taken")
    end
  end
end
