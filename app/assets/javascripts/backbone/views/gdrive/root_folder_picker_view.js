Gather.Views.GDrive.RootFolderPickerView = class RootFolderPickerView extends Backbone.View {
  initialize(options) {
    this.appId = options.clientId.split("-")[0];
    this.accessToken = options.accessToken;
    this.apiKey = options.apiKey;
    this.saveFolderUrl = options.saveFolderUrl;
    this.testMode = options.testMode;
    gapi.load("picker");
  }

  get events() {
    return {
      "click #pick-folder": "showPicker"
    };
  }

  showPicker() {
    /*
     * In test env, we can't call out to the picker so we just short circuit
     * and pretend we selected some random folder ID.
     */
    if (this.testMode) {
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
      .setOAuthToken(this.accessToken)
      .addView(view)
      .setTitle("Please select root folder")
      .setDeveloperKey(this.apiKey)
      .setCallback(this.callback.bind(this))
      .build();
    picker.setVisible(true);
  }

  callback(data) {
    if (data.action === google.picker.Action.PICKED) {
      this.saveFolder(data.docs[0].id);
    }
  }

  saveFolder(id) {
    $.ajax({
      url: this.saveFolderUrl,
      method: "PUT",
      data: {folder_id: id},
      success: () => window.location.reload()
    });
  }
};
