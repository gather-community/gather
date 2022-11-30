import {Controller} from "@hotwired/stimulus";
import {jsonFetch} from "../../utils/json_fetch";

export default class extends Controller<HTMLFormElement> {
  static values = {
    clientId: String,
    apiKey: String,
    accessToken: String,
    rootFolderId: String,
    ingestFilesUrl: String,
    testMode: Boolean
  };

  declare clientIdValue: string;
  declare apiKeyValue: string;
  declare accessTokenValue: string;
  declare rootFolderIdValue: string;
  declare ingestFilesUrlValue: string;
  declare testModeValue: boolean;
  declare gapiLoaded: boolean;

  connect(): void {
    gapi.load("picker", () => {
      this.gapiLoaded = true;
    });
  }

  get appId(): string {
    return this.clientIdValue.split("-")[0];
  }

  showPicker(): void {
    /*
     * In test env, we can't call out to the picker so we just short circuit
     * and pretend we selected some random folder ID.
     */
    if (this.testModeValue) {
      // this.saveFolder("xxxxxxxxZC4JyX21yUUwxxxxxxxx");
    }

    const view = new google.picker.DocsView(google.picker.ViewId.DOCS);
    view.setIncludeFolders(true);
    view.setSelectFolderEnabled(true);
    view.setMode(google.picker.DocsViewMode.LIST);
    view.setParent(this.rootFolderIdValue);
    view.setQuery("-is:starred");

    const picker = new google.picker.PickerBuilder()
      .enableFeature(google.picker.Feature.NAV_HIDDEN)
      .enableFeature(google.picker.Feature.MULTISELECT_ENABLED)
      .setAppId(this.appId)
      .setOAuthToken(this.accessTokenValue)
      .addView(view)
      .setTitle("Please select files for Gather to use")
      .setMaxItems(1000)
      .setDeveloperKey(this.apiKeyValue)
      .setCallback(this.callback.bind(this))
      .build();
    picker.setVisible(true);
  }

  callback(data: {docs:[{id: string}], action: string}): void {
    if (data.action === google.picker.Action.PICKED) {
      jsonFetch(this.ingestFilesUrlValue, {
        method: "PUT",
        body: {picked: data}
      });
    }
  }
}
