Mess.Views.FileUploadView = Backbone.View.extend

  initialize: (params) ->
    @tmpId = @$('[name=tmp_id]').val()
    @model = @$('[name=model]').val()
    @attribute = @$('[name=attribute]').val()

    @dropzone = new Dropzone @$el.get(0),
      maxFiles: 1
      init: ->
        @on 'addedfile', ->
          # Replace existing file if present
          @removeFile(@files[0]) if @files[1]

  events:
    'click a.delete': 'deleteFile'

  deleteFile: (e) ->
    e.preventDefault()
    if @dropzone.files[0]
      @dropzone.removeFile(@dropzone.files[0])
      $.post("/uploads/#{@tmpId}", {_method: "DELETE", model: @model, attribute: @attribute})
