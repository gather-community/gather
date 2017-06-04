# Handles printing of directory. Loads full album with table format on the fly.
Gather.Views.People.DirectoryPrintView = Gather.Views.PrintView.extend

  print: ->
    window.print()
