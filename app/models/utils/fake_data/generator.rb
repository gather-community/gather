# frozen_string_literal: true

module Utils
  module FakeData
    class Generator
      include FactoryBot::Syntax::Methods

      def generate_samples
        # Implemented optionally by subclasses
      end

      def cleanup_on_error
        # Implemented optionally by subclasses
      end

      protected

      def resource_path(str)
        Rails.root.join("lib/random_data/#{str}").to_s
      end

      def load_yaml(path)
        YAML.load_file(resource_path("data/#{path}"))
      end

      def distrib_rand(*pcts)
        rnd = rand(1..100)
        cum = 0
        pcts.size.times do |i|
          cum += pcts[i]
          return i if rnd <= cum
        end
        pcts.size
      end

      def bool_prob(pct)
        rand(100) < pct
      end

      def unique_set(size)
        hash = {}
        loop do
          hash[yield] = 1
          break if hash.size == size
        end
        hash.keys
      end
    end
  end
end
