import {Controller} from "@hotwired/stimulus";
import {choiceModal, type ModalChoice} from "../../utils/modal";
import {submitHiddenForm} from "../../utils/hidden_form";

/*
 * Delete button on an event's show page when there's a choice to make: the event recurs and/or
 * appears on more than one calendar. Asks which calendars and which occurrences to delete (the same
 * two questions as drag-to-move in calendar_view.js), then submits a DELETE to the eventlet.
 *
 * The steps are built server-side (EventletDecorator#delete_prompts) so their text is localized and
 * escaped, and so they only offer choices the user is allowed to make. The last step shown doubles
 * as the confirmation.
 */
interface PromptStep {
  title: string;
  content: string;
  choices: ModalChoice<string>[];
}

interface Prompts {
  // Null when the event is on one calendar; the calendar scope is then "all".
  calendar: PromptStep | null;
  // Null when the event doesn't recur; the series scope is then "series".
  series: Record<string, PromptStep> | null;
}

export default class extends Controller<HTMLAnchorElement> {
  static values = {occurrenceStart: Number, prompts: Object};

  declare readonly occurrenceStartValue: number;
  declare readonly hasOccurrenceStartValue: boolean;
  declare readonly promptsValue: Prompts;

  async confirm(event: Event) {
    event.preventDefault();
    event.stopImmediatePropagation();

    const {calendar, series} = this.promptsValue;

    const calendarScope = calendar ? await this.ask(calendar) : "all";
    if (!calendarScope) {
      return;
    }

    const seriesScope = series ? await this.ask(series[calendarScope]) : "series";
    if (!seriesScope) {
      return;
    }

    const fields: Record<string, string> = {
      "calendars_eventlet[calendar_scope]": calendarScope,
      "calendars_eventlet[series_scope]": seriesScope,
    };
    if (this.hasOccurrenceStartValue) {
      fields["calendars_eventlet[occurrence_start]"] = String(this.occurrenceStartValue);
    }
    submitHiddenForm(this.element.href, "delete", fields);
  }

  private ask(step: PromptStep): Promise<string | null> {
    return choiceModal(step.content, step.choices, {title: step.title});
  }
}
