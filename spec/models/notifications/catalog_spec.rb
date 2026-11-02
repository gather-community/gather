# frozen_string_literal: true

require "rails_helper"

describe Notifications::Catalog do
  # Every email must be accounted for on the notification preferences page.
  # See the Email section of CLAUDE.md.
  it "lists every mailer action exactly once" do
    Rails.application.eager_load!
    app_dir = Rails.root.join("app").to_s
    mailers = ActionMailer::Base.descendants.select do |klass|
      klass.name && Object.const_source_location(klass.name)&.first&.start_with?(app_dir)
    end
    actions = mailers.flat_map do |mailer|
      # AuthMailer inherits actions from Devise::Mailer that we don't use, so only check its own.
      names = (mailer <= Devise::Mailer) ? mailer.public_instance_methods(false) : mailer.action_methods
      names.map { |name| "#{mailer.name}##{name}" }
    end
    expect(actions).to include("MealMailer#meal_reminder", "AuthMailer#reset_password_instructions")

    missing = actions.reject { |action| described_class::BY_MAILER_ACTION.key?(action) }
    expect(missing).to be_empty, "Add these to Notifications::Catalog: #{missing.join(", ")}"

    listed = described_class.all.flat_map(&:mailer_actions)
    expect(listed).to match_array(listed.uniq)
    stale = listed - actions
    expect(stale).to be_empty, "These catalog entries don't match a mailer action: #{stale.join(", ")}"
  end

  it "gives every listed kind a section" do
    described_class.listed.each do |kind|
      expect(described_class::SECTIONS).to include(kind.section)
    end
  end
end
