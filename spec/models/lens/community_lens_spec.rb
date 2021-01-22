# frozen_string_literal: true

require "rails_helper"

describe CommunityLens do
  let!(:community1) { Defaults.community }
  let!(:community2) { create(:community, name: "Community2", slug: "community2") }
  let!(:community3) { create(:community, name: "Community3", slug: "community3") }
  let(:context) do
    double(view_context: view_context, multi_community?: true, current_community: community3,
           current_cluster: Defaults.cluster)
  end
  let(:view_context) { double(select_tag: nil, load_communities_in_cluster: Community.all, url_for: "") }
  let(:storage) { double(action_store: {}) }
  let(:subdomain) { false }
  let(:lens) do
    params = {options: {}, context: context, route_params: route_params, storage: storage, set: nil}
    params[:options][:clearable] = clearable
    params[:options][:subdomain] = subdomain
    described_class.new(**params)
  end

  before do
    allow(lens).to receive(:h).and_return(view_context)
  end

  describe "#selection" do
    subject(:selection) { lens.selection }

    context "with clearable lens" do
      let(:clearable) { true }

      context "without subdomain mode" do
        context "when nothing selected" do
          let(:route_params) { {} }
          it { is_expected.to match_array(Community.all.to_a) }
        end

        context "when default community selected" do
          let(:route_params) { {community: "this"} }
          it { is_expected.to eq(community3) }
        end

        context "when other community selected" do
          let(:route_params) { {community: "community2"} }
          it { is_expected.to eq(community2) }
        end

        context "when other community selected via ID" do
          let(:route_params) { {community: community2.id.to_s} }
          it { is_expected.to eq(community2) }
        end
      end

      context "with subdomain mode" do
        let(:subdomain) { true }

        context "when nothing selected" do
          let(:route_params) { {} }
          it { is_expected.to match_array(Community.all.to_a) }
        end

        context "when default community selected" do
          let(:route_params) { {community: "this"} }
          it { is_expected.to eq(community3) }
        end

        context "when other community selected" do
          # This shouldn't happen since we should be redirecting. Current community trumps lens.
          let(:route_params) { {community: "community2"} }
          it { is_expected.to eq(community3) }
        end
      end
    end

    context "without clearable lens" do
      let(:clearable) { false }

      context "without subdomain mode" do
        context "when nothing selected" do
          let(:route_params) { {} }
          it { is_expected.to eq(community3) }
        end

        context "when default community selected" do
          let(:route_params) { {community: "community3"} }
          it { is_expected.to eq(community3) }
        end

        context "when other community selected" do
          let(:route_params) { {community: "community2"} }
          it { is_expected.to eq(community2) }
        end
      end

      context "with subdomain mode" do
        let(:subdomain) { true }

        context "when nothing selected" do
          let(:route_params) { {} }
          it { is_expected.to eq(community3) }
        end

        context "when default community selected" do
          let(:route_params) { {community: "this"} }
          it { is_expected.to eq(community3) }
        end

        context "when other community selected" do
          # This shouldn't happen since we should be redirecting. Current community trumps lens.
          let(:route_params) { {community: "community2"} }
          it { is_expected.to eq(community3) }
        end
      end
    end
  end

  describe "#render" do
    context "when lens is clearable" do
      let(:clearable) { true }

      context "when nothing given" do
        let(:route_params) { {} }

        it "includes 'all', puts current community as first option with 'this', nil selection" do
          expect(view_context).to receive(:options_for_select)
            .with([["All Communities", nil], %w[Community3 this],
                   %w[Default default], %w[Community2 community2]], nil)
            .and_return("<option ...>")
          lens.render
        end
      end

      context "when current community explicitly given" do
        let(:route_params) { {community: "this"} }

        it "selects current community" do
          expect(view_context).to receive(:options_for_select)
            .with([["All Communities", nil], %w[Community3 this],
                   %w[Default default], %w[Community2 community2]], "this")
            .and_return("<option ...>")
          lens.render
        end
      end

      context "when other option explicitly given" do
        let(:route_params) { {community: "community2"} }

        it "selects appropriate community" do
          expect(view_context).to receive(:options_for_select)
            .with([["All Communities", nil], %w[Community3 this],
                   %w[Default default], %w[Community2 community2]], "community2")
            .and_return("<option ...>")
          lens.render
        end
      end
    end

    context "when lens is not clearable" do
      let(:clearable) { false }

      context "when nothing given" do
        let(:route_params) { {} }

        it "puts current community as first option, nil selection" do
          expect(view_context).to receive(:options_for_select)
            .with([%w[Community3 community3], %w[Default default], %w[Community2 community2]], nil)
            .and_return("<option ...>")
          lens.render
        end
      end

      context "when first option explicitly given" do
        let(:route_params) { {community: "community3"} }

        it "selects appropriate community" do
          expect(view_context).to receive(:options_for_select)
            .with([%w[Community3 community3], %w[Default default], %w[Community2 community2]], nil)
            .and_return("<option ...>")
          lens.render
        end
      end

      context "when other option explicitly given" do
        let(:route_params) { {community: "community2"} }

        it "selects appropriate community" do
          expect(view_context).to receive(:options_for_select)
            .with([%w[Community3 community3], %w[Default default], %w[Community2 community2]], "community2")
            .and_return("<option ...>")
          lens.render
        end
      end
    end
  end
end
