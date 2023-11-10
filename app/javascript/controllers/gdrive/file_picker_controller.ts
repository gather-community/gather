import {Controller} from "@hotwired/stimulus";
import {jsonFetch} from "../../utils/json_fetch";

export default class extends Controller<HTMLFormElement> {
  static values = {
    clientId: String,
    accessToken: String,
    rootFolderId: String,
    ingestUrl: String,
    testMode: Boolean,
    searchToken: String,
    communityName: String,
  };

  declare clientIdValue: string;
  declare accessTokenValue: string;
  declare rootFolderIdValue: string;
  declare ingestUrlValue: string;
  declare testModeValue: boolean;
  declare searchTokenValue: string;
  declare communityNameValue: string;
  declare gapiLoaded: boolean;

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
    // view.setParent("1ag0wl1RWHigAz65IPuu8cooeuqgwYNg-");
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

  callback(data: {docs:[{id: string}], action: string}): void {
    if (data.action === google.picker.Action.PICKED) {
      jsonFetch(this.ingestUrlValue, {
        method: "PUT",
        body: {picked: data}
      });
    }
  }
}
