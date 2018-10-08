Gather.Views.Meals.SignupView = Backbone.View.extend
  initialize: (options) ->

  events:
    'cocoon:after-insert .meal_signups_signup': 'selectDistinctItemId'

  selectDistinctItemId: (e) ->
    newLine = @$(e.target).prev('.nested-fields')
    return if newLine.length == 0
    prevItemIds = newLine.prevAll('.nested-fields').find('select[name$="[item_id]"]')
      .map(-> $(this).val()).get()
    newLine.find('select[name$="[item_id]"] option').each ->
      itemId = $(this).attr('value')
      return true if prevItemIds.indexOf(itemId) != -1
      newLine.find('select[name$="[item_id]"]').val(itemId)
      false # Break out of the loop
