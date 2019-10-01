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

  describe "autolink" do
    let(:input) { "Foo https://bar.com Bar" }
    it { is_expected.to eq(%(<p>Foo <a href="https://bar.com">https://bar.com</a> Bar</p>\n)) }
  end

  describe "tables" do
    let(:input) { "|A|B|C|\n|---|---|---|\n|1|2|3|\n" }
    it do
      is_expected.to eq(%(<table>\n<thead>\n<tr>\n<th>A</th>\n<th>B</th>\n<th>C</th>\n</tr>\n</thead>) +
        %(\n<tbody>\n<tr>\n<td>1</td>\n<td>2</td>\n<td>3</td>\n</tr>\n</tbody>\n</table>\n))
    end
  end

  describe "strikethrough" do
    let(:input) { "Foo ~~Bar~~" }
    it { is_expected.to eq(%(<p>Foo <del>Bar</del></p>\n)) }
  end
end
