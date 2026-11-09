# frozen_string_literal: true

# Faker files its Norwegian and Finnish data under nb-NO and fi-FI, which aren't Gather locales, so Faker fell
# back to English names and places for sample data in those languages. This makes the same data available
# under nb and fi. Faker finds it there because it uses the current I18n locale.
faker_locales = File.join(Gem.loaded_specs.fetch("faker").full_gem_path, "lib", "locales")
{nb: "nb-NO", fi: "fi-FI"}.to_h do |ours, fakers|
  [ours, {faker: YAML.load_file(File.join(faker_locales, "#{fakers}.yml")).fetch(fakers).fetch("faker")}]
end
