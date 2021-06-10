Gather.Views.Calendars.ColorFieldView = Backbone.View.extend
  initialize: (params) ->
    @textBox = @$('input[type=text]')
    @update()

  events:
    'keyup input[type=text]': 'update'
    'click .swatch': 'pickColor'

  update: ->
    value = @textBox.val()
    color = if value.match(/^#[0-9a-f]{6}$/) then value else '#999999'
    @textBox.css('background-color', color)

  pickColor: (event) ->
    @textBox.val(@$(event.currentTarget).data('color'))
    @textBox.trigger('keyup')
