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
    searchToken: String,
    communityName: String,
  };

  static targets = ["instructions", "loader"];

  declare clientIdValue: string;
  declare accessTokenValue: string;
  declare rootFolderIdValue: string;
  declare ingestUrlValue: string;
  declare ingestStatusUrlValue: string;
  declare ingestInitialStatusValue: string;
  declare testModeValue: boolean;
  declare searchTokenValue: string;
  declare communityNameValue: string;
  declare gapiLoaded: boolean;

  declare readonly instructionsTarget: HTMLElement
  declare readonly loaderTarget: HTMLElement

  declare pollingInterval: number;

  connect(): void {
    gapi.load("picker", () => {
      this.gapiLoaded = true;
    });

    // If ingestion is in progress, we want to behave as if the
    // user had clicked the ingestion button.
    if (this.ingestInitialStatusValue === 'new' || this.ingestInitialStatusValue === 'in_progress') {
      this.startPollingForIngestStatus();
    }
  }

  get appId(): string {
    return this.clientIdValue.split("-")[0];
  }

  showPicker(): void {
    const view = new google.picker.DocsView(google.picker.ViewId.DOCS);
    view.setIncludeFolders(true);
    view.setSelectFolderEnabled(true);
    view.setMode(google.picker.DocsViewMode.LIST);
    view.setQuery(`owner:me ${this.searchTokenValue}`);

    const picker = new google.picker.PickerBuilder()
      .enableFeature(google.picker.Feature.NAV_HIDDEN)
      .enableFeature(google.picker.Feature.MULTISELECT_ENABLED)
      .setAppId(this.appId)
      .setOAuthToken(this.accessTokenValue)
      .addView(view)
      .setTitle(`Please select files ending with ${this.searchTokenValue}. Hold the Shift key to select multiple.`)
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
      this.startPollingForIngestStatus();
    }
  }

  startPollingForIngestStatus(): void {
    this.instructionsTarget.style.display = 'none';
    this.loaderTarget.style.display = 'block';
    this.pollingInterval = setInterval(this.pollForIngestStatus.bind(this), 2000);
  }

  async pollForIngestStatus(): Promise<void> {
    const result = await jsonFetch(this.ingestStatusUrlValue, {
      method: "GET"
    });

    if (result.status === "done") {
      clearInterval(this.pollingInterval);
      this.loaderTarget.style.display = 'none';
      this.instructionsTarget.innerHTML = result.instructions;
      this.instructionsTarget.style.display = '';
    }
  }
}
