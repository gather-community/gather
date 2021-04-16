# frozen_string_literal: true

AttributeNormalizer.configure do |config|
  config.normalizers[:email] = lambda do |value, _options|
    if value.is_a?(String)
      value.strip.blank? ? nil : value.downcase.strip
    else
      value
    end
  end

  config.normalizers[:downcase] = lambda do |value, _options|
    value&.downcase
  end
end
