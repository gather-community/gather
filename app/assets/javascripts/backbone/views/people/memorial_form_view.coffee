Gather.Views.People.MemorialFormView = Backbone.View.extend

  initialize: (options) ->
    @birthYears = options.birthYears

  events:
    'change #people_memorial_user_id': 'userChanged'

  userChanged: (event) ->
    userId = parseInt(@$(event.target).val())
    console.log(@birthYears[userId])
    if (year = @birthYears[userId])
      @$('#people_memorial_birth_year').val(year)
