# frozen_string_literal: true

module Utils
  module Generators
    # Superclass for generator classes.
    class Generator
      include FactoryBot::Syntax::Methods

      def generate_seed_data
        # Implemented optionally by subclasses
      end

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

      # psych 4+ made YAML.load_file safe by default, which rejects the timestamp scalars and
      # symbol keys in the data files. These are trusted, checked-in fixtures, so permit both.
      def load_yaml(path)
        YAML.safe_load_file(resource_path("data/#{path}"), permitted_classes: [Symbol, Time])
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

      def in_community_timezone
        tz = Time.zone
        Time.zone = community.settings.time_zone
        yield
        Time.zone = tz
      end
    end
  end
end
