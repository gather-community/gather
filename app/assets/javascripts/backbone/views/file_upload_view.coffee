Mess.Views.FileUploadView = Backbone.View.extend

  initialize: (params) ->
    @dzForm = @$('.dropzone')
    @mainForm = @$('form:not(.dropzone)')
    @params = params

    @tmpId = @dzForm.find('[name=tmp_id]').val()
    @model = @dzForm.find('[name=model]').val()
    @attribute = @dzForm.find('[name=attribute]').val()
    @id = @dzForm.find('[name=id]').val()

    @initDropzone()

  initDropzone: ->
    view = @
    @dropzone = new Dropzone @dzForm.get(0),
      maxFiles: 1
      maxFilesize: @params.maxFilesize
      init: ->
        dz = this
        dz.on 'addedfile', ->
          dz.removeFile(dz.files[0]) if dz.files[1] # Replace existing file if present
          view.setMainPhotoDestroyFlag(false)
          view.showExisting(false)

  events:
    'click a.delete': 'delete'

  delete: (e) ->
    e.preventDefault()
    @deleteTmpFile()
    @setMainPhotoDestroyFlag(true)
    @showExisting(false)

  deleteTmpFile: ->
    if @dropzone.files[0]
      @dropzone.removeFile(@dropzone.files[0])
      $.post "/uploads/#{@tmpId}",
        _method: "DELETE"
        model: @model
        attribute: @attribute
        tmp_id: @tmpId

  setMainPhotoDestroyFlag: (bool) ->
    @mainForm.find('#user_photo_destroy').val(if bool then '1' else '0')

  showExisting: (bool) ->
    @dzForm.find('.existing')[if bool then 'show' else 'hide']()
