module Lens
  class Lens
    attr_reader :name, :options

    def initialize(name:, options:)
      @name = name
      @options = options
    end

    def to_s
      name.to_s
    end

    def required?
      !!options[:required]
    end
  end
end
