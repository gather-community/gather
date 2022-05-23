Gather.Views.GDrive.RootFolderPickerView = class RootFolderPickerView extends Backbone.View {
  initialize(options) {
    this.appId = options.clientId.split("-")[0];
    this.accessToken = options.accessToken;
    this.apiKey = options.apiKey;
    gapi.load("picker");
  }

  get events() {
    return {
      "click #pick-folder": "showPicker"
    };
  }

  showPicker() {
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
      const doc = data.docs[0];
    }
  }
};
