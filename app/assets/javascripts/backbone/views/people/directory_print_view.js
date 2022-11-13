Gather.Views.People.DirectoryPrintView = Gather.Views.PrintView.extend({
  initialize(params) {
    this.viewType = params.viewType;
  },

  print() {
    if (!this.viewType || (this.viewType === "album")) {
      Gather.loadingIndicator.show();
      this.$("#printable-directory-album").load("/users.html?printalbum=1", () => {
        this.$("#printable-directory-album").waitForImages(function() {
          Gather.loadingIndicator.hide();
          window.print();
        });
      });
    } else {
      window.print();
    }
  }
});
