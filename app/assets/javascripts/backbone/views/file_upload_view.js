Gather.Views.FileUploadView = Backbone.View.extend({
  initialize(options) {
    this.wrapper = this.$(".dropzone-wrapper");
    this.dzForm = this.$(".dropzone");
    this.mainForm = this.$("form:not(.dropzone):not(.dropzone-error-form)");

    this.maxSize = options.maxSize;
    this.destroyFlag = false;

    this.attrib = this.dzForm.find("[name=attrib]").val();

    this.initDropzone();
  },

  initDropzone() {
    const view = this;
    let options = {
      maxFiles: 1,
      maxFilesize: this.maxSize ? this.maxSize / 1024 / 1024 : undefined,
      filesizeBase: 1024,
      transformFile(file, done) {
        view.copyIntoMemory(file, done, this);
      },
      init() {
        const dz = this;
        dz.on("addedfile", file => view.fileAdded.apply(view, [file, dz]));
        dz.on("success", (file, response) => view.fileUploaded.apply(view, [file, response, dz]));
      }
    };
    options = Object.assign(options, I18n.t("dropzone")); // Add translations
    this.dropzone = new Dropzone(this.dzForm.get(0), options);
  },

  events: {
    "click a.delete": "delete"
  },

  fileAdded(file, dz) {
    if (dz.files[1]) {
      dz.removeFile(dz.files[0]);
    } // Replace existing dragged file if present
    this.setViewState("new");
    this.setSignedId(""); // Will be set when upload finished
    this.hideMainRequestErrors();
    this.setDestroyFlag(false);
  },

  fileUploaded(file, response, dz) {
    this.setSignedId(response.blob_id);
  },

  /*
   * On iOS (every browser, since they all use WebKit), uploading a photo straight from the picker
   * sends the request with an empty body (Content-Length: 0), which Rails rejects as "Bad Request".
   * Reading the bytes into an in-memory Blob first gives the request a real body.
   * Dropzone takes the filename from the original file, so the Blob doesn't need one.
   */
  copyIntoMemory(file, done, dz) {
    file.arrayBuffer()
      .then((buffer) => {
        if (buffer.byteLength !== file.size) {
          throw new Error(`Read ${buffer.byteLength} of ${file.size} bytes`);
        }
        done(new window.Blob([buffer], {type: file.type}));
      })
      .catch(() => {
        /*
         * Dropzone's internal failure path (marks the file as errored and shows the message).
         * There's no public equivalent for a failure before the request is sent.
         */
        dz._errorProcessing([file], I18n.t("dropzone.dictFileUnreadable"));
      });
  },

  delete(e) {
    e.preventDefault();
    this.setDestroyFlag(true);
    this.setSignedId("");
    this.hideMainRequestErrors();
    this.setViewState("empty");
    if (this.hasNewFile()) {
      this.dropzone.removeFile(this.dropzone.files[0]);
    }
  },

  hasNewFile() {
    return !!this.dropzone.files[0];
  },

  setDestroyFlag(bool) {
    this.destroyFlag = bool;
    this.mainForm.find(`[id$=_${this.attrib}_destroy]`).val(bool ? "1" : "0");
  },

  setSignedId(id) {
    this.mainForm.find(`[id$=_${this.attrib}_new_signed_id]`).val(id);
  },

  hideMainRequestErrors() {
    this.dzForm.find(".main-request-errors").hide();
  },

  showExisting(bool) {
    this.dzForm.find(".existing")[bool ? "show" : "hide"]();
  },

  setViewState(state) {
    this.wrapper.removeClass("state-new");
    this.wrapper.removeClass("state-empty");
    this.wrapper.removeClass("state-existing");
    this.wrapper.addClass(`state-${state}`);
  },

  isUploading() {
    return (this.dropzone.getUploadingFiles().length > 0) || (this.dropzone.getQueuedFiles().length > 0);
  },

  /*
   * Part of a ducktype defined by the jquery.dirtyForms plugin.
   * The file upload is dirty if any files have been dragged,
   * or if the existing file has been marked for deletion.
   */
  isDirty(node) {
    if (node.get(0) === this.mainForm.get(0)) {
      return this.hasNewFile() || this.destroyFlag;
    }
  }
});
