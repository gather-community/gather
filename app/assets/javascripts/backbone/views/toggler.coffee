# Toggles things on and off based on data-toggle, data-toggle-on, data-toggle-off attribs
Gather.Views.Toggler = Backbone.View.extend
  el: 'body'

  events:
    'click [data-toggle]': 'toggle'

  toggle: (event) ->
    id = @$(event.currentTarget).data('toggle')
    ons = @$("[data-toggle-on=\"#{id}\"]")
    offs = @$("[data-toggle-off=\"#{id}\"]")
    state = if ons.length > 0 then ons.is(':visible') else !offs.is(':visible')
    ons.toggle(!state)
    offs.toggle(state)
    event.preventDefault()
