# frozen_string_literal: true

require "rails_helper"

describe "multi-events form AJAX endpoint" do
  let(:community) { create(:community) }
  let(:user) { create(:user, community: community) }
  let!(:calendar1) { create(:calendar, name: "Main Hall", community: community) }
  let!(:calendar2) { create(:calendar, name: "Garden", community: community) }

  before do
    use_user_subdomain(user)
    sign_in(user)
  end

  describe "POST /calendars/multi_events/form" do
    let(:base_params) do
      {
        calendars_event: {
          name: "Test Event",
          starts_at: "2026-05-10 10:00",
          ends_at: "2026-05-10 11:00",
          all_day: "0",
          origin_page: "",
          calendar_slots_attributes: {}
        }
      }
    end

    context "with no calendar selected" do
      it "renders the form partial without events summary" do
        post(form_calendars_multi_events_path, params: base_params)
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("multi-event-summary")
      end
    end

    context "with one calendar selected" do
      let(:params_with_calendar) do
        base_params.deep_merge(
          calendars_event: {
            calendar_slots_attributes: {
              "0" => {_destroy: "0", calendar_id: calendar1.id.to_s, customize_times: "0"}
            }
          }
        )
      end

      it "renders the form partial with events summary" do
        post(form_calendars_multi_events_path, params: params_with_calendar)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("multi-event-summary")
        expect(response.body).to include("Main Hall")
      end

      context "when calendar has guidelines" do
        before { calendar1.update!(guidelines: "Main Hall rules") }

        it "renders guidelines section" do
          post(form_calendars_multi_events_path, params: params_with_calendar)
          expect(response).to have_http_status(:ok)
          expect(response.body).to include("Main Hall rules")
        end
      end
    end

    context "with a slot marked for destruction" do
      let(:params_with_destroyed_slot) do
        base_params.deep_merge(
          calendars_event: {
            calendar_slots_attributes: {
              "0" => {_destroy: "0", calendar_id: calendar1.id.to_s, customize_times: "0"},
              "1" => {_destroy: "1", calendar_id: calendar2.id.to_s, customize_times: "0"}
            }
          }
        )
      end

      it "only shows the active slot in the events summary list" do
        post(form_calendars_multi_events_path, params: params_with_destroyed_slot)
        expect(response).to have_http_status(:ok)
        # Events summary should contain Main Hall but not Garden
        summary_match = response.body.match(%r{<ul class="multi-event-summary">(.*?)</ul>}m)
        expect(summary_match).to be_present
        expect(summary_match[1]).to include("Main Hall")
        expect(summary_match[1]).not_to include("Garden")
      end

      it "preserves _destroy=1 in the re-rendered hidden field for the destroyed slot" do
        post(form_calendars_multi_events_path, params: params_with_destroyed_slot)
        expect(response).to have_http_status(:ok)
        # The hidden _destroy field for calendar2's slot should have value="1"
        expect(response.body).to match(/calendar_slots_attributes.*_destroy.*value="1"/m)
      end
    end

    context "touched-field filtering" do
      let(:invalid_params) do
        # name over the 24-char limit, ends_at before starts_at, no calendar
        base_params.deep_merge(
          calendars_event: {
            name: "X" * 30,
            starts_at: "2026-05-10 11:00",
            ends_at: "2026-05-10 10:00"
          }
        )
      end

      it "suppresses all field errors and :base errors when nothing is touched" do
        post(form_calendars_multi_events_path, params: invalid_params)
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("is too long")
        expect(response.body).not_to include("must be after start time")
        expect(response.body).not_to include("At least one calendar must be selected")
      end

      it "shows only the error for the touched field" do
        post(form_calendars_multi_events_path,
          params: invalid_params.merge(_touched: ["calendars_event[name]"]))
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("is too long")
        expect(response.body).not_to include("must be after start time")
        expect(response.body).not_to include("At least one calendar must be selected")
      end

      it "never shows :base errors regardless of touched list" do
        post(form_calendars_multi_events_path,
          params: invalid_params.merge(_touched: ["calendars_event[name]", "calendars_event[base]"]))
        expect(response.body).not_to include("At least one calendar must be selected")
      end
    end
  end
end
