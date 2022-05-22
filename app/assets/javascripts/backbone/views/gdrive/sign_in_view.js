// Array of API discovery doc URLs for APIs used by the quickstart
const DISCOVERY_DOCS = ["https://www.googleapis.com/discovery/v1/apis/drive/v3/rest"];

// Authorization scopes required by the API; multiple scopes can be included, separated by spaces.
const SCOPES = "https://www.googleapis.com/auth/drive.file";

Gather.Views.GDrive.SignInView = class PickFolderView extends Backbone.View {
  initialize(options) {
    this.cmtyGoogleId = options.cmtyGoogleId;
    this.clientId = options.clientId;
    this.apiKey = options.apiKey;
    gapi.load("client:auth2", this.initClient.bind(this));
  }

  get events() {
    return {
      "click #sign-in": "signIn"
    };
  }

  initClient() {
    gapi.client.init({
      apiKey: this.apiKey,
      clientId: this.clientId,
      discoveryDocs: DISCOVERY_DOCS,
      scope: SCOPES
    }).then(() => {
      const authInstance = gapi.auth2.getAuthInstance();
      authInstance.isSignedIn.listen(this.handleSigninStatusChange.bind(this));
      this.handleSigninStatusChange(authInstance.isSignedIn.get(), true);
    }, (error) => {
      console.log(error);
    });
  }

  signIn() {
    const options = new gapi.auth2.SigninOptionsBuilder();
    options.setPrompt("select_account");
    gapi.auth2.getAuthInstance().signIn(options);
  }

  handleSigninStatusChange(isSignedIn, isOnPageLoad) {
    const authInstance = gapi.auth2.getAuthInstance();
    if (isSignedIn) {
      const profile = authInstance.currentUser.get().getBasicProfile();
      if (profile.getEmail() === this.cmtyGoogleId) {
        this.toggleSignedIn(true);
      } else {
        if (!isOnPageLoad) {
          this.showWrongGoogleIdError();
        }
        authInstance.signOut();
      }
    } else {
      this.toggleSignedIn(false);
    }
  }

  toggleSignedIn(isSignedIn) {
    this.$("#signed-in").toggle(isSignedIn);
    this.$("#not-signed-in").toggle(!isSignedIn);
  }
};
