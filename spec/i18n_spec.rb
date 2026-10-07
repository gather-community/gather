# frozen_string_literal: true

require "rails_helper"
require "i18n/tasks"

# Config for the key checks lives in config/i18n-tasks.yml. There is deliberately no "files are normalized"
# check: `i18n-tasks normalize` strips YAML comments, which our locale files rely on.
describe "i18n" do
  let(:i18n) { I18n::Tasks::BaseTask.new }

  it "has no keys used in code but missing from en" do
    missing_keys = i18n.missing_keys(locales: [i18n.base_locale])
    expect(missing_keys).to be_empty,
      "Missing #{missing_keys.leaves.count} i18n keys, " \
      "run `bundle exec i18n-tasks missing -l en` to show them"
  end

  it "has no unused keys" do
    unused_keys = i18n.unused_keys(locales: [i18n.base_locale])
    expect(unused_keys).to be_empty,
      "#{unused_keys.leaves.count} unused i18n keys, " \
      "run `bundle exec i18n-tasks unused -l en` to show them. " \
      "If a key is looked up dynamically, add it to ignore_unused in config/i18n-tasks.yml."
  end

  it "has consistent interpolations across locales" do
    inconsistent = i18n.inconsistent_interpolations
    expect(inconsistent).to be_empty,
      "#{inconsistent.leaves.count} i18n keys have inconsistent interpolations, " \
      "run `bundle exec i18n-tasks check-consistent-interpolations` to show them"
  end

  it "has an up-to-date JS translations export" do
    config = YAML.load_file(Rails.root.join("config/i18n-js.yml"))
    committed_paths = config["translations"].pluck("file")
    Dir.mktmpdir do |dir|
      config["translations"].each { |group| group["file"] = File.join(dir, group["file"]) }
      I18nJS.call(config: config)
      committed_paths.each do |path|
        expect(File.read(File.join(dir, path))).to eq(Rails.root.join(path).read),
          "#{path} is out of date. Regenerate it with " \
          "`bundle exec i18n export -c config/i18n-js.yml -r config/environment.rb`"
      end
    end
  end
end
