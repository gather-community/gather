# frozen_string_literal: true

module Communities
  class SignupActionForm
    include ActiveModel::Conversion
    include ActiveModel::Validations
    include ActiveModel::Validations::Callbacks
    extend AttributeNormalizer::ClassMethods

    DECISION_OPTIONS = %i[approve deny].freeze

    attr_accessor :decision, :message

    normalize_attributes :message

    def self.model_name
      ActiveModel::Name.new(self, nil, "Communities::SignupAction")
    end

    def model_name
      self.class.model_name
    end

    validates :decision, presence: true, inclusion: {in: DECISION_OPTIONS.map(&:to_s)}
    validates :message, presence: true,
      length: {maximum: Communities::Signup::MESSAGE_MAX_LENGTH}, allow_blank: true

    def initialize(params = {})
      @decision = params[:decision]
      @message = params[:message]
    end

    def new_record?
      true
    end

    def persisted?
      false
    end

    def id
      nil
    end
  end
end
