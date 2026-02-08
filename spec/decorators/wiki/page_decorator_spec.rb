# frozen_string_literal: true

require "rails_helper"

describe Wiki::PageDecorator do
  let(:decorator) { page.decorate }
  subject(:rendered) { decorator.formatted_content[29..-12] } # Removes outer div and p tags.

  describe "sanitization" do
    let(:content) do
      '<b>Bold</b> <iframe src="http://f.oo"></iframe> <a href="foo/bar"></a> <script></script> Stuff'
    end
    let(:page) { create(:wiki_page, content: content) }

    it "leaves iframe tags but removes script tags" do
      is_expected.to eq('<b>Bold</b> <iframe src="http://f.oo"></iframe> <a href="foo/bar"></a>  Stuff')
    end
  end

  describe "linkification" do
    let!(:other_page) { create(:wiki_page, title: "Another Page") }
    let(:page) { create(:wiki_page, content: content) }

    context "regular link" do
      let(:content) { "A link to [[Another Page]] stuff" }
      it { is_expected.to eq(%(A link to <a href="/wiki/another-page">Another Page</a> stuff)) }
    end

    context "piped link" do
      let(:content) { "A link to [[Another Page|this page]]" }
      it { is_expected.to eq(%(A link to <a href="/wiki/another-page">this page</a>)) }
    end

    context "not found link" do
      let(:content) { "A link to [[Non-existent Page]]" }

      before do
        allow(decorator).to receive(:can_create_page?).and_return(can_create_page)
      end

      context "with page creation permission" do
        let(:can_create_page) { true }
        it do
          is_expected.to eq(+%(A link to <a class=\"not-found\" ) <<
            %(href=\"/wiki/new?title=Non-existent+Page\">Non-existent Page</a>))
        end
      end

      context "without page creation permission" do
        let(:can_create_page) { false }
        it do
          is_expected.to eq(+%(A link to <a class=\"not-found\" ) <<
            %(href=\"/wiki/notfound\">Non-existent Page</a>))
        end
      end
    end
  end

  describe "data fetch" do
    let(:content) { "foo" }
    let(:data_source) { "http://example.com" }
    let(:attribs) { {content: content, data_source: data_source} }
    let(:page) { create(:wiki_page, attribs) }

    def stub_http_success(body)
      response = double(body: body)
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      http = double
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:read_timeout=)
      allow(http).to receive(:request).and_return(response)
      allow(Net::HTTP).to receive(:new).and_return(http)
    end

    def stub_http_error(exception)
      http = double
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:read_timeout=)
      allow(http).to receive(:request).and_raise(exception)
      allow(Net::HTTP).to receive(:new).and_return(http)
    end

    def stub_http_error_response(code)
      response = double(body: "Error", code: code.to_s)
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
      http = double
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:read_timeout=)
      allow(http).to receive(:request).and_return(response)
      allow(Net::HTTP).to receive(:new).and_return(http)
    end

    context "with no errors" do
      before do
        if attribs[:data_source].present?
          stub_http_success('{"name":"Rolph","pants":[{"type":"jeans"},{"type":"cords"}]}')
        end
      end

      context "with data_source but no template content" do
        let(:content) { "* Normal stuff" }

        it "returns normal content" do
          expect(decorator.formatted_content.delete("\n"))
            .to eq('<div class="wiki-content"><ul><li>Normal stuff</li></ul></div>')
        end
      end

      context "with template content but no data_source" do
        let(:content) { "Hello {{myvar}}" }
        let(:data_source) { nil }

        it "returns normal content" do
          expect(decorator.formatted_content.delete("\n"))
            .to eq('<div class="wiki-content"><p>Hello {{myvar}}</p></div>')
        end
      end

      context "with data_source and template" do
        let(:content) { "{{name}}: {{#pants}}_{{type}}_{{/pants}}" }

        it "returns normal content with markdown converted" do
          expect(decorator.formatted_content.delete("\n"))
            .to eq('<div class="wiki-content"><p>Rolph: <em>jeans</em><em>cords</em></p></div>')
        end
      end
    end

    context "error handling" do
      context "with invalid protocol" do
        let(:data_source) { "ftp://example.com/data.json" }

        it do
          expect_empty_formatted_content
          expect(decorator.data_fetch_error).to eq("Data source URL must use HTTP or HTTPS")
        end
      end

      context "with socket error" do
        before { stub_http_error(SocketError) }

        it do
          expect_empty_formatted_content
          expect(decorator.data_fetch_error).to eq("Could not connect to data source")
        end
      end

      context "with http error" do
        before { stub_http_error_response(404) }

        it do
          expect_empty_formatted_content
          expect(decorator.data_fetch_error).to eq("Could not connect to data source")
        end
      end

      context "with json error" do
        before { stub_http_success("badjson") }

        it do
          expect_empty_formatted_content
          expect(decorator.data_fetch_error).to eq("Invalid JSON")
        end
      end

      context "with template syntax error" do
        before do
          page.update_column(:content, "{{1&na.me}}")
          stub_http_success("{}")
        end

        it do
          expect_empty_formatted_content
          expect(decorator.data_fetch_error).to eq("Template Error: Unclosed tag, Line 1")
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
        expect(decorator.template_error).to eq("Template Error: Unclosed tag, Line 1")
      end
    end
  end
end
