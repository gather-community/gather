Gather.Views.People.MemorialView = Backbone.View.extend

  initialize: (options) ->
    @draftMessageChanged()

  events:
    'keyup #people_memorial_message_body': 'draftMessageChanged'

  draftMessageChanged: ->
    blank = @$('#people_memorial_message_body').val().trim() == ''
    @$('.people--memorial-message-form .btn-primary').toggle(!blank)
