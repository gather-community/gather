Mess.Views.DirtyChecker = Backbone.View.extend

  initialize: (params) ->
    @$el.dirtyForms
      helpers: params.helpers

  # A helper that lets other code manually mark the form as dirty by adding the .dirty-flag class.
  customDirtyHelper:
    isDirty: ($node, index) ->
      if $node.is('form') then $node.hasClass('dirty-flag') else false
    setClean: ($node, index, excludeIgnored) ->
      $node.removeClass('dirty-flag') if $node.is('form')
