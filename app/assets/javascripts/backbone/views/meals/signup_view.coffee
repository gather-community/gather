Gather.Views.Meals.SignupView = Backbone.View.extend
  initialize: (options) ->

  events:
    'cocoon:after-insert': 'selectDistinctTypeId'

  selectDistinctTypeId: (e) ->
    newLine = @$(e.target).prev('.nested-fields')
    return if newLine.length == 0
    prevTypeIds = newLine.prevAll('.nested-fields').find('select[name$="[type_id]"]')
      .map(-> $(this).val()).get()
    newLine.find('select[name$="[type_id]"] option').each ->
      typeId = $(this).attr('value')
      return true if prevTypeIds.indexOf(typeId) != -1
      newLine.find('select[name$="[type_id]"]').val(typeId)
      false # Break out of the loop
