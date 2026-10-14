# frozen_string_literal: true

require "rails_helper"
require "open3"

# Runs the i18n linters: hard-coded user-facing strings (Gather/HardCodedString and the erb_lint checks) and
# locale-unaware money formatting (Gather/NumberToCurrency). What they cover is configured in .rubocop.yml
# and .erb_lint.yml. See "User-Facing Strings" in CLAUDE.md.
describe "i18n linters" do
  it "find nothing in Ruby files" do
    output, status = Open3.capture2e("bundle", "exec", "rubocop",
      "--only", "Gather/HardCodedString,Gather/NumberToCurrency", "--format", "simple", chdir: Rails.root.to_s)
    expect(status).to be_success, output
  end

  it "find nothing in views" do
    output, status = Open3.capture2e("bundle", "exec", "erb_lint", "--lint-all", chdir: Rails.root.to_s)
    expect(status).to be_success, output
  end
end
