import {Controller} from "@hotwired/stimulus";
import {jsonFetch} from "../../utils/json_fetch";

export default class extends Controller<HTMLFormElement> {
  static values = {
    clientId: String,
    accessToken: String,
    rootFolderId: String,
    ingestUrl: String,
    ingestStatusUrl: String,
    ingestInitialStatus: String,
    testMode: Boolean,
    communityName: String,
    orgUserId: String,
  };

  static targets = ["instructions", "loader", "progress", "total"];

  declare clientIdValue: string;
  declare accessTokenValue: string;
  declare rootFolderIdValue: string;
  declare ingestUrlValue: string;
  declare ingestStatusUrlValue: string;
  declare ingestInitialStatusValue: string;
  declare testModeValue: boolean;
  declare communityNameValue: string;
  declare orgUserIdValue: string;
  declare gapiLoaded: boolean;

  declare readonly instructionsTarget: HTMLElement;
  declare readonly loaderTarget: HTMLElement;
  declare readonly progressTarget: HTMLElement;
  declare readonly totalTarget: HTMLElement;

  declare pollingInterval: number;

  connect(): void {
    gapi.load("picker", () => {
      this.gapiLoaded = true;
    });

    /*
     * If ingest is in progress, we want to behave as if the
     * user had clicked the ingest button.
     */
    if (this.ingestInitialStatusValue === "new" || this.ingestInitialStatusValue === "in_progress") {
      this.startPollingForIngestStatus();
    }
  }

  get appId(): string {
    return this.clientIdValue.split("-")[0];
  }

  showPicker(): void {
    const view = new google.picker.DocsView(google.picker.ViewId.DOCS);
    view.setIncludeFolders(false);
    view.setSelectFolderEnabled(false);
    view.setOwnedByMe(true);
    view.setMode(google.picker.DocsViewMode.LIST);
    // @ts-ignore: Property 'setQuery' does not exist on type 'DocsView'. (Yes it does!)
    view.setQuery(`to:${this.orgUserIdValue}`);

    const picker = new google.picker.PickerBuilder()
      .enableFeature(google.picker.Feature.NAV_HIDDEN)
      .enableFeature(google.picker.Feature.MULTISELECT_ENABLED)
      .setAppId(this.appId)
      .setOAuthToken(this.accessTokenValue)
      .addView(view)
      .setTitle("Please select all files. Hold the SHIFT key while clicking to select multiple files.")
      .setMaxItems(100)
      .setCallback(this.callback.bind(this))
      .build();
    picker.setVisible(true);
  }

  async callback(data: {docs:[{id: string}], action: string}): Promise<void> {
    if (data.action === google.picker.Action.PICKED) {
      jsonFetch(this.ingestUrlValue, {
        method: "PUT",
        body: {file_ids: data.docs.map((f) => f.id)}
      });
      this.setProgress(0, data.docs.length);
      this.startPollingForIngestStatus();
    }
  }

  startPollingForIngestStatus(): void {
    this.instructionsTarget.style.display = "none";
    this.loaderTarget.style.display = "block";
    this.pollingInterval = setInterval(this.pollForIngestStatus.bind(this), 2000);
  }

  async pollForIngestStatus(): Promise<void> {
    const result = await jsonFetch(this.ingestStatusUrlValue, {
      method: "GET"
    });

    if (result.status === "done" || result.status === "failed") {
      clearInterval(this.pollingInterval);
      this.loaderTarget.style.display = "none";
      this.instructionsTarget.innerHTML = result.instructions;
      this.instructionsTarget.style.display = "";
    } else {
      this.setProgress(result.progress, result.total);
    }
  }

  setProgress(progress: number, total: number) {
    this.progressTarget.innerHTML = (progress + 1).toString();
    this.totalTarget.innerHTML = total.toString();
  }
}
