Gather.Views.FileUploadView = Backbone.View.extend({
  initialize(options) {
    this.wrapper = this.$('.dropzone-wrapper');
    this.dzForm = this.$('.dropzone');
    this.mainForm = this.$('form:not(.dropzone):not(.dropzone-error-form)');

    this.maxSize = options.maxSize;
    this.destroyFlag = false;

    this.attrib = this.dzForm.find('[name=attrib]').val();

    this.initDropzone();
  },

  initDropzone() {
    const view = this;
    let options = {
      maxFiles: 1,
      maxFilesize: this.maxSize ? this.maxSize / 1024 / 1024 : undefined,
      filesizeBase: 1024,
      init() {
        const dz = this;
        dz.on('addedfile', file => view.fileAdded.apply(view, [file, dz]));
        dz.on('success', (file, response) => view.fileUploaded.apply(view, [file, response, dz]));
      }
    };
    options = Object.assign(options, I18n.t("dropzone")); // Add translations
    this.dropzone = new Dropzone(this.dzForm.get(0), options);
  },

  events: {
    'click a.delete': 'delete'
  },

  fileAdded(file, dz) {
    if (dz.files[1]) { dz.removeFile(dz.files[0]); } // Replace existing dragged file if present
    this.setViewState('new');
    this.setSignedId(''); // Will be set when upload finished
    this.hideMainRequestErrors();
    this.setDestroyFlag(false);
  },

  fileUploaded(file, response, dz) {
    this.setSignedId(response.blob_id);
  },

  delete(e) {
    e.preventDefault();
    this.setDestroyFlag(true);
    this.setSignedId('');
    this.hideMainRequestErrors();
    this.setViewState('empty');
    if (this.hasNewFile()) { this.dropzone.removeFile(this.dropzone.files[0]); }
  },

  hasNewFile() {
    return !!this.dropzone.files[0];
  },

  setDestroyFlag(bool) {
    this.destroyFlag = bool;
    this.mainForm.find(`[id$=_${this.attrib}_destroy]`).val(bool ? '1' : '0');
  },

  setSignedId(id) {
    this.mainForm.find(`[id$=_${this.attrib}_new_signed_id]`).val(id);
  },

  hideMainRequestErrors() {
    this.dzForm.find('.main-request-errors').hide();
  },

  showExisting(bool) {
    this.dzForm.find('.existing')[bool ? 'show' : 'hide']();
  },

  setViewState(state) {
    this.wrapper.removeClass('state-new');
    this.wrapper.removeClass('state-empty');
    this.wrapper.removeClass('state-existing');
    this.wrapper.addClass(`state-${state}`);
  },

  isUploading() {
    return (this.dropzone.getUploadingFiles().length > 0) || (this.dropzone.getQueuedFiles().length > 0);
  },

  // Part of a ducktype defined by the jquery.dirtyForms plugin.
  // The file upload is dirty if any files have been dragged,
  // or if the existing file has been marked for deletion.
  isDirty(node) {
    if (node.get(0) === this.mainForm.get(0)) {
      return this.hasNewFile() || this.destroyFlag;
    }
  }
});
