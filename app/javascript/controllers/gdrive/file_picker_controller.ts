import {Controller} from "@hotwired/stimulus";
import {jsonFetch} from "../../utils/json_fetch";

export default class extends Controller<HTMLFormElement> {
  static values = {
    clientId: String,
    accessToken: String,
    rootFolderId: String,
    ingestUrl: String,
    ingestStatusUrl: String,
    testMode: Boolean,
    searchToken: String,
    communityName: String,
  };

  static targets = ["loader"];

  declare clientIdValue: string;
  declare accessTokenValue: string;
  declare rootFolderIdValue: string;
  declare ingestUrlValue: string;
  declare ingestStatusUrlValue: string;
  declare testModeValue: boolean;
  declare searchTokenValue: string;
  declare communityNameValue: string;
  declare gapiLoaded: boolean;

  declare readonly loaderTarget: HTMLElement

  declare pollingInterval: number;

  connect(): void {
    gapi.load("picker", () => {
      this.gapiLoaded = true;
      this.showPicker();
    });
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
      this.loaderTarget.style.display = 'block';
      await jsonFetch(this.ingestUrlValue, {
        method: "PUT",
        body: {picked: data}
      });
      this.startPollingForIngestStatus();
    }
  }

  startPollingForIngestStatus(): void {
    this.pollingInterval = setInterval(this.pollForIngestStatus.bind(this), 2000);
  }

  async pollForIngestStatus(): Promise<void> {
    const result = await jsonFetch(this.ingestStatusUrlValue, {
      method: "GET"
    });

    if (result.status == "done") {
      clearInterval(this.pollingInterval);
      this.loaderTarget.style.display = '';
    }
  }
}
