# frozen_string_literal: true

require "rails_helper"

# Just for test purposes
class TestLens < Lens::SelectLens
  param_name :view
  select_prompt :album
  possible_options %i[table tableall]
  i18n_key "simple_form.options.user.view"
end

describe Lens::SelectLens do
  let(:community) { create(:community) }
  let(:context) { double }
  let(:storage) { double(action_store: {}) }
  let(:lens) do
    TestLens.new(options: {}, context: context, route_params: route_params, storage: storage, set: nil)
  end

  describe "#active" do
    subject(:active) { lens.active? }

    context "when value is blank (which happens when the prompt is chosen)" do
      let(:route_params) { {view: ""} }
      it { is_expected.to be(false) }
    end

    context "when value is not the default" do
      let(:route_params) { {view: "table"} }
      it { is_expected.to be(true) }
    end
  end

  describe "#render" do
    let(:view_context) { double }

    before do
      expect(lens).to receive(:h).twice.and_return(view_context)
    end

    context "when default value chosen" do
      let(:route_params) { {view: ""} }

      it "calls expected methods" do
        expect(view_context).to receive(:options_for_select)
          .with([["Table", :table], ["Table w/ Inactive", :tableall]], nil).and_return("<option ...>")
        expect(view_context).to receive(:select_tag).with(
          :view,
          "<option ...>",
          class: "form-control view-lens",
          "data-param-name": :view,
          onchange: "this.form.submit();",
          prompt: "Album"
        ).and_return("<select ...>")
        expect(lens.render).to eq("<select ...>")
      end
    end

    context "when other value chosen" do
      let(:route_params) { {view: "table"} }

      it "calls expected methods" do
        expect(view_context).to receive(:options_for_select)
          .with([["Table", :table], ["Table w/ Inactive", :tableall]], "table").and_return("<option ...>")
        expect(view_context).to receive(:select_tag).and_return("<select ...>")
        expect(lens.render).to eq("<select ...>")
      end
    end
  end
end
