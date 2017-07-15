Gather.Views.FileUploadView = Backbone.View.extend

  initialize: (params) ->
    @dzForm = @$('.dropzone')
    @mainForm = @$('form:not(.dropzone)')
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
    view = @
    @dropzone = new Dropzone @dzForm.get(0),
      maxFiles: 1
      maxFilesize: @params.maxFilesize
      thumbnailWidth: width
      thumbnailHeight: height
      init: ->
        dz = this
        dz.on 'addedfile', (file) -> view.fileAdded.apply(view, [file, dz])

  events:
    'click a.delete': 'delete'

  fileAdded: (file, dz) ->
    dz.removeFile(dz.files[0]) if dz.files[1] # Replace existing dragged file if present
    @dzForm.addClass('existing-deleted') if @dzForm.is('.has-existing')
    @setMainPhotoDestroyFlag(false)

  delete: (e) ->
    e.preventDefault()
    @deleteTmpFile()
    @setMainPhotoDestroyFlag(true)
    @dzForm.addClass('existing-deleted')

  deleteTmpFile: ->
    if @hasNewFile()
      @dropzone.removeFile(@dropzone.files[0])
      $.post "/uploads/#{@tmpId}",
        _method: "DELETE"
        model: @model
        attribute: @attribute
        tmp_id: @tmpId

  hasNewFile: ->
    !!@dropzone.files[0]

  setMainPhotoDestroyFlag: (bool) ->
    if @dzForm.is('.has-existing')
      @mainPhotoDestroy = bool
      @mainForm.find('#user_photo_destroy').val(if bool then '1' else '0')

  showExisting: (bool) ->
    @dzForm.find('.existing')[if bool then 'show' else 'hide']()

  # Part of a ducktype defined by the jquery.dirtyForms plugin.
  # The file upload is dirty if any files have been dragged,
  # or if the existing file has been marked for deletion.
  isDirty: (node) ->
    if node.get(0) == @mainForm.get(0)
      @hasNewFile() || @mainPhotoDestroy
