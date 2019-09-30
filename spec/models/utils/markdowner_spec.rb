# frozen_string_literal: true

require "rails_helper"

describe Utils::Markdowner do
  let(:options) { {} }
  subject(:output) { described_class.instance.render(input, **options) }

  context "with safe and unsafe tags" do
    let(:input) { "apple **banana** <em>bold</em> <script>foo</script> <iframe>bar</iframe>" }
    it { is_expected.to eq("<p>apple <strong>banana</strong> <em>bold</em> foo bar</p>\n") }
  end

  context "with extra allowed tags" do
    let(:options) { {extra_allowed_tags: %w[iframe]} }
    let(:input) { "apple **banana** <em>bold</em> <script>foo</script> <iframe>bar</iframe>" }
    it { is_expected.to eq("<p>apple <strong>banana</strong> <em>bold</em> foo <iframe>bar</iframe></p>\n") }
  end

  context "with link target" do
    let(:input) { %(<a href="/xyz" target="_blank">Foo</a>) }
    it { is_expected.to eq(%(<p><a href="/xyz" target="_blank">Foo</a></p>\n)) }
  end

  describe "line breaks" do
    context "simple" do
      let(:input) { "A\nB" }
      it { is_expected.to eq("<p>A\nB</p>\n") }
    end

    context "with html block" do
      let(:input) { "A\nB\n\n<div>C\nD</div>\n\nE\n\nF" }
      it { is_expected.to eq("<p>A\nB</p>\n\n<div>C\nD</div>\n\n<p>E</p>\n\n<p>F</p>\n") }
    end
  end
end
