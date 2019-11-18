Gather.Views.FileUploadView = Backbone.View.extend

  initialize: (params) ->
    @dzForm = @$('.dropzone-form')
    @mainForm = @$('form:not(.dropzone-form):not(.dropzone-error-form)')
    @errorForm = @$('.dropzone-error-form')
    @params = params
    @mainPhotoDestroy = false

    @tmpId = @dzForm.find('[name=tmp_id]').val()
    @model = @dzForm.find('[name=model]').val()
    @attribute = @dzForm.find('[name=attribute]').val()
    @id = @dzForm.find('[name=id]').val()

    @initDropzone()

  initDropzone: ->
    # Should match $thumbnail-size in dropzone.scss
    width = @dzForm.data('width')
    height = @dzForm.data('height')
    view = this
    @dropzone = new Dropzone @dzForm.get(0),
      maxFiles: 1
      maxFilesize: null # Handle this on the server side. Was not working properly on client side.
      thumbnailWidth: width
      thumbnailHeight: height
      init: ->
        dz = this
        dz.on 'addedfile', (file) -> view.fileAdded.apply(view, [file, dz])
        dz.on 'success', (file, response) -> view.fileUploaded.apply(view, [file, response, dz])

  events:
    'click a.delete': 'delete'

  fileAdded: (file, dz) ->
    dz.removeFile(dz.files[0]) if dz.files[1] # Replace existing dragged file if present
    @dzForm.addClass('existing-deleted') if @dzForm.is('.has-existing')
    @setMainPhotoDestroyFlag(false)

  fileUploaded: (file, response, dz) ->
    @mainForm.find('[id$=_photo_new_signed_id]').val(response.blob_id)
    @mainForm.find('[id$=_photo_destroy]').val('')
    @errorForm.hide()

  delete: (e) ->
    e.preventDefault()
    @setMainPhotoDestroyFlag(true)
    @mainForm.find('[id$=_photo_new_signed_id]').val('')
    @mainForm.find('[id$=_photo_destroy]').val('1')
    @dzForm.addClass('existing-deleted')
    @dropzone.removeFile(@dropzone.files[0]) if @hasNewFile()

  hasNewFile: ->
    !!@dropzone.files[0]

  setMainPhotoDestroyFlag: (bool) ->
    if @dzForm.is('.has-existing')
      @mainPhotoDestroy = bool
      @mainForm.find('[id$=_photo_destroy]').val(if bool then '1' else '0')

  showExisting: (bool) ->
    @dzForm.find('.existing')[if bool then 'show' else 'hide']()

  isUploading: ->
    @dropzone.getUploadingFiles().length > 0 || @dropzone.getQueuedFiles().length > 0;

  # Part of a ducktype defined by the jquery.dirtyForms plugin.
  # The file upload is dirty if any files have been dragged,
  # or if the existing file has been marked for deletion.
  isDirty: (node) ->
    if node.get(0) == @mainForm.get(0)
      @hasNewFile() || @mainPhotoDestroy
