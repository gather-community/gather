Gather.Views.DirtyChecker = Backbone.View.extend

  initialize: (params) ->
    params.helpers = params.helpers || []
    params.helpers.push(@datetimePickerHelper)
    params.helpers.push(@hiddenInputHelper)
    @$el.dirtyForms
      helpers: params.helpers

  events:
    'cocoon:after-insert': 'rescan'
    'cocoon:after-remove': 'rescan'
    'gather:select2inserted': 'rescan'

  rescan: ->
    @$el.dirtyForms('rescan')

  # A helper that lets other code manually mark the form as dirty by adding the .dirty-flag class.
  customDirtyHelper:
    isDirty: ($node) ->
      if $node.is('form') then $node.hasClass('dirty-flag') else false
    setClean: ($node) ->
      $node.removeClass('dirty-flag') if $node.is('form')

  # A helper that checks datetimepickers for dirtiness.
  datetimePickerHelper:
    isDirty: ($node) ->
      dirty = false
      $node.find('.input-group.datetimepicker').each ->
        orig = moment($(this).find('input').data('initial-value'))
        current = $(this).data('DateTimePicker').date()
        if orig && current && !orig.isSame(current) || (!orig && !current)
          if $.DirtyForms.debug
            console.warn('[DirtyFormDateTimePickerHelper] Found dirty picker ', this)
          dirty = true
          return false
      dirty

  # Checks hidden inputs with the data-orig-val attribute to see if they have changed.
  hiddenInputHelper:
    isDirty: ($node) ->
      dirty = false
      $node.find('input[type=hidden][data-orig-val]').each ->
        console.log($(this).val())
        console.log($(this).data('orig-val'))
        if $(this).val().toString() != $(this).data('orig-val').toString()
          dirty = true
          return false
      dirty
