Mess.Views.UserFormView = Backbone.View.extend

  initialize: ->
    Dropzone.options.userPhoto =
      maxFiles: 1
      init: ->
        @on 'addedfile', ->
          # Replace existing file if present
          @removeFile(@files[0]) if @files[1]
