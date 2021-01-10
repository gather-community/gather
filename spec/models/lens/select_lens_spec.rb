# frozen_string_literal: true

require "rails_helper"

# Just for test purposes
class TestLens < Lens::SelectLens
  param_name :view
  possible_options %i[album table tableall]
  i18n_key "simple_form.options.user.view"

  protected

  def excluded_options
    route_params[:foo] ? [:tableall] : []
  end
end

describe Lens::SelectLens do
  let(:community) { create(:community) }
  let(:context) { double }
  let(:default_option) { nil }
  let(:storage) { double(action_store: {}) }
  let(:lens) do
    params = {options: {}, context: context, route_params: route_params, storage: storage, set: nil}
    params[:options][:default] = default_option unless default_option.nil?
    TestLens.new(**params)
  end

  describe "#active" do
    subject(:active) { lens.active? }

    context "when no value is given" do
      let(:route_params) { {} }
      it { is_expected.to be(false) }
    end

    context "without explicitly defined default" do
      context "when first option is explicitly given" do
        let(:route_params) { {view: "album"} }
        it { is_expected.to be(false) }
      end

      context "when value given is not the default" do
        let(:route_params) { {view: "table"} }
        it { is_expected.to be(true) }
      end
    end

    context "with explicitly defined default" do
      let(:default_option) { :tableall }

      context "when explicitly defined default is given" do
        let(:route_params) { {view: "tableall"} }
        it { is_expected.to be(false) }
      end

      context "when value given is not the default" do
        let(:route_params) { {view: "table"} }
        it { is_expected.to be(true) }
      end
    end
  end

  describe "#render" do
    let(:view_context) { double }

    before do
      expect(lens).to receive(:h).twice.and_return(view_context)
    end

    shared_examples_for "has no selected option" do
      it "calls expected methods" do
        expect(view_context).to receive(:options_for_select)
          .with([["Album", :album], ["Table", :table], ["Table w/ Inactive", :tableall]], nil)
          .and_return("<option ...>")
        expect(view_context).to receive(:select_tag).with(
          :view,
          "<option ...>",
          class: "form-control view-lens",
          "data-param-name": :view,
          onchange: "this.form.submit();"
        ).and_return("<select ...>")
        expect(lens.render).to eq("<select ...>")
      end
    end

    context "when default value chosen explicitly" do
      let(:route_params) { {view: "album"} }
      it_behaves_like "has no selected option"
    end

    context "when default value chosen via no value given" do
      let(:route_params) { {} }
      it_behaves_like "has no selected option"
    end

    context "when other value chosen" do
      let(:route_params) { {view: "table"} }

      it "passes expected selected option" do
        expect(view_context).to receive(:options_for_select)
          .with([["Album", :album], ["Table", :table], ["Table w/ Inactive", :tableall]], "table")
          .and_return("<option ...>")
        expect(view_context).to receive(:select_tag) do |_p, _q, options|
          expect(options[:prompt]).to be_nil
        end
        lens.render
      end
    end

    context "when options excluded" do
      let(:route_params) { {foo: 1} }

      it "passes expected options" do
        expect(view_context).to receive(:options_for_select)
          .with([["Album", :album], ["Table", :table]], nil).and_return("<option ...>")
        expect(view_context).to receive(:select_tag) do |_p, _q, options|
          expect(options[:prompt]).to be_nil
        end
        lens.render
      end
    end
  end
end
