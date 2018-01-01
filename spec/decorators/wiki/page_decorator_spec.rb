require 'rails_helper'

describe Wiki::PageDecorator do
  describe "data fetch" do
    let(:content) { "foo" }
    let(:data_source) { "http://example.com" }
    let(:attribs) { {content: content, data_source: data_source} }
    let(:page) { create(:wiki_page, attribs) }
    let(:decorator) { page.decorate }

    context "with no errors" do
      before do
        if attribs[:data_source].present?
          allow(Kernel).to receive(:open).and_return(
            '{"name":"Rolph","pants":[{"type":"jeans"},{"type":"cords"}]}')
        end
      end

      context "with data_source but no template content" do
        let(:content) { "* Normal stuff" }

        it "returns normal content" do
          expect(decorator.formatted_content.gsub("\n", "")).
            to eq '<div class="wiki-content"><ul><li>Normal stuff</li></ul></div>'
        end
      end

      context "with template content but no data_source" do
        let(:content) { "Hello {{myvar}}" }
        let(:data_source) { nil }

        it "returns normal content" do
          expect(decorator.formatted_content.gsub("\n", "")).
            to eq '<div class="wiki-content"><p>Hello {{myvar}}</p></div>'
        end
      end

      context "with data_source and template" do
        let(:content) { "{{name}}: {{#pants}}_{{type}}_{{/pants}}" }

        it "returns normal content with markdown converted" do
          expect(decorator.formatted_content.gsub("\n", "")).
            to eq '<div class="wiki-content"><p>Rolph: <em>jeans</em><em>cords</em></p></div>'
        end
      end
    end

    context "error handling" do
      context "with socket error" do
        before do
          expect(Kernel).to receive(:open).and_raise(SocketError)
        end

        it do
          expect_empty_formatted_content
          expect(decorator.data_fetch_error).to eq "Couldn't connect to server"
        end
      end

      context "with http error" do
        before do
          expect(Kernel).to receive(:open).and_raise(OpenURI::HTTPError.new("404 Not Found", nil))
        end

        it do
          expect_empty_formatted_content
          expect(decorator.data_fetch_error).to eq "404 Not Found"
        end
      end

      context "with json error" do
        before do
          expect(Kernel).to receive(:open).and_return("badjson")
        end

        it do
          expect_empty_formatted_content
          expect(decorator.data_fetch_error).to eq "Invalid JSON"
        end
      end

      context "with template syntax error" do
        let(:content) { "{{1&na.me}}" }

        before do
          expect(Kernel).to receive(:open).and_return("{}")
        end

        it do
          expect_empty_formatted_content
          expect(decorator.data_fetch_error).to eq "Template Error: Unclosed tag, Line 1"
        end
      end

      def expect_empty_formatted_content
        expect(decorator.formatted_content).to eq('<div class="wiki-content"></div>')
      end
    end
  end

  describe "#template_error" do
    let(:decorator) { create(:wiki_page, content: content).decorate }

    context "with valid template" do
      let(:content) { "{{#people}}{{name}}{{/people}}" }

      it "returns nil" do
        expect(decorator.template_error).to be_nil
      end
    end

    context "with invalid template" do
      let(:content) { "{{1&na.me}}" }

      it "returns error" do
        expect(decorator.template_error).to eq "Template Error: Unclosed tag, Line 1"
      end
    end
  end
end
