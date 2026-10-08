# frozen_string_literal: true

require "rails_helper"
require "open3"

# Runs the hard-coded string linters over the files whose strings have been moved to locale files. Which
# files those are is configured in .rubocop.yml (Gather/HardCodedString Include) and .erb_lint.yml (glob).
# See "User-Facing Strings" in CLAUDE.md.
describe "hard-coded user-facing strings" do
  it "are absent from converted Ruby files" do
    output, status = Open3.capture2e("bundle", "exec", "rubocop", "--only", "Gather/HardCodedString",
      "--format", "simple", chdir: Rails.root.to_s)
    expect(status).to be_success, output
  end

  it "are absent from converted views" do
    output, status = Open3.capture2e("bundle", "exec", "erb_lint", "--lint-all", chdir: Rails.root.to_s)
    expect(status).to be_success, output
  end
end
