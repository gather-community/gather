Gather.Views.FileUploadView = Backbone.View.extend

  initialize: (options) ->
    @dzForm = @$('.dropzone')
    @mainForm = @$('form:not(.dropzone):not(.dropzone-error-form)')
    @errorForm = @$('.dropzone-error-form')

    @maxSize = options.maxSize
    @destroyFlag = false

    @attrib = @dzForm.find('[name=attrib]').val()

    @initDropzone()

  initDropzone: ->
    # Should match $thumbnail-size in dropzone.scss
    width = @dzForm.data('width')
    height = @dzForm.data('height')
    view = this
    options =
      maxFiles: 1
      maxFilesize: if @maxSize then @maxSize / 1024 / 1024
      filesizeBase: 1024
      thumbnailWidth: width
      thumbnailHeight: height
      init: ->
        dz = this
        dz.on 'addedfile', (file) -> view.fileAdded.apply(view, [file, dz])
        dz.on 'success', (file, response) -> view.fileUploaded.apply(view, [file, response, dz])
    options = Object.assign(options, I18n.t("dropzone")) # Add translations
    @dropzone = new Dropzone @dzForm.get(0), options

  events:
    'click a.delete': 'delete'

  fileAdded: (file, dz) ->
    dz.removeFile(dz.files[0]) if dz.files[1] # Replace existing dragged file if present
    @dzForm.addClass('existing-deleted') if @dzForm.is('.has-existing')
    @setSignedId('') # Will be set when upload finished
    @setDestroyFlag(false)

  fileUploaded: (file, response, dz) ->
    @setSignedId(response.blob_id)
    @errorForm.hide()

  delete: (e) ->
    e.preventDefault()
    @setDestroyFlag(true)
    @setSignedId('')
    @dzForm.addClass('existing-deleted')
    @dropzone.removeFile(@dropzone.files[0]) if @hasNewFile()

  hasNewFile: ->
    !!@dropzone.files[0]

  setDestroyFlag: (bool) ->
    @destroyFlag = bool
    @mainForm.find("[id$=_#{@attrib}_destroy]").val(if bool then '1' else '0')

  setSignedId: (id) ->
    @mainForm.find("[id$=_#{@attrib}_new_signed_id]").val(id)

  showExisting: (bool) ->
    @dzForm.find('.existing')[if bool then 'show' else 'hide']()

  isUploading: ->
    @dropzone.getUploadingFiles().length > 0 || @dropzone.getQueuedFiles().length > 0;

  # Part of a ducktype defined by the jquery.dirtyForms plugin.
  # The file upload is dirty if any files have been dragged,
  # or if the existing file has been marked for deletion.
  isDirty: (node) ->
    if node.get(0) == @mainForm.get(0)
      @hasNewFile() || @destroyFlag
