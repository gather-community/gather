import {Controller} from "@hotwired/stimulus";

export default class extends Controller<HTMLFormElement> {
  static values = {
    clientId: String,
    apiKey: String,
    accessToken: String,
    saveFolderUrl: String,
    testMode: Boolean
  };

  declare clientIdValue: string;
  declare apiKeyValue: string;
  declare accessTokenValue: string;
  declare saveFolderUrlValue: string;
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
      this.saveFolder("xxxxxxxxZC4JyX21yUUwxxxxxxxx");
    }

    const view = new google.picker.DocsView(google.picker.ViewId.FOLDERS);
    view.setIncludeFolders(true);
    view.setSelectFolderEnabled(true);
    view.setMode(google.picker.DocsViewMode.LIST);
    view.setParent("root");

    const picker = new google.picker.PickerBuilder()
      .enableFeature(google.picker.Feature.NAV_HIDDEN)
      .setAppId(this.appId)
      .setOAuthToken(this.accessTokenValue)
      .addView(view)
      .setTitle("Please select root folder")
      .setDeveloperKey(this.apiKeyValue)
      .setCallback(this.callback.bind(this))
      .build();
    picker.setVisible(true);
  }

  callback(data: {docs:[{id: string}], action: string}): void {
    if (data.action === google.picker.Action.PICKED) {
      this.saveFolder(data.docs[0].id);
    }
  }

  saveFolder(id: string): void {
    $.ajax({
      url: this.saveFolderUrlValue,
      method: "PUT",
      data: {folder_id: id},
      success: () => window.location.reload()
    });
  }
}
