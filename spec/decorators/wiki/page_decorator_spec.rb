require 'rails_helper'

describe Wiki::PageDecorator do
  describe "mustache syntax" do
    let(:page) { create(:wiki_page, attribs) }
    let(:decorator) { page.decorate }

    before do
      if attribs[:data_source].present?
        allow(page).to receive(:fetch_data).and_return(
          name: "Rolph", pants: [{type: "jeans"}, {type: "cords"}])
      end
    end

    context "with data_source but no template content" do
      let(:attribs) { {content: "* Normal stuff", data_source: "http://foo.com"} }

      it "returns normal content" do
        expect(decorator.formatted_content.gsub("\n", "")).
          to eq '<div class="wiki-content"><ul><li>Normal stuff</li></ul></div>'
      end
    end

    context "with template content but no data_source" do
      let(:attribs) { {content: "Hello {{myvar}}"} }

      it "returns normal content" do
        expect(decorator.formatted_content.gsub("\n", "")).
          to eq '<div class="wiki-content"><p>Hello {{myvar}}</p></div>'
      end
    end

    context "with data_source and template" do
      let(:attribs) { {content: "{{name}}: {{#pants}}_{{type}}_{{/pants}}", data_source: "http://foo.com"} }

      it "returns normal content with markdown converted" do
        expect(decorator.formatted_content.gsub("\n", "")).
          to eq '<div class="wiki-content"><p>Rolph: <em>jeans</em><em>cords</em></p></div>'
      end
    end
  end
end
