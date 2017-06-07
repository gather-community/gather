# Handles printing of directory.
Gather.Views.People.DirectoryPrintView = Gather.Views.PrintView.extend

  initialize: (params) ->
    @viewType = params.viewType

  print: ->
    if !@viewType || @viewType == "album"
      Gather.loadingIndicator.show()
      @$("#printable-directory-album").load "/users.html?printalbum=1", =>
        @$("#printable-directory-album").waitForImages ->
          Gather.loadingIndicator.hide()
          window.print()
    else
      window.print()
