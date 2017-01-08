# Adds a class to select boxes that have prompt currently selected.
# Allows for placeholder-like styling.
# Looks for has-prompt class on select tag.
Mess.Views.SelectPromptStyler = Backbone.View.extend
  el: 'body'

  initialize: ->
    @$('select.has-prompt').trigger('change')

  events:
    'change select.has-prompt': 'changed'

  changed: (e) ->
    select = @$(e.currentTarget)
    if select.find('option').first().is(':selected')
      select.addClass('prompt-selected')
    else
      select.removeClass('prompt-selected')
