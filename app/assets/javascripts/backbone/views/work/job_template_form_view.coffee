Gather.Views.Work.JobTemplateFormView = Backbone.View.extend

  initialize: (options) ->
    @$('#work_job_template_meal_related').trigger('change')

  events:
    'change #work_job_template_time_type': 'toggleOffsetsAndHours'
    'change #work_job_template_meal_related': 'toggleOffsetsAndHours'

  toggleOffsetsAndHours: ->
    @$('.form-group.work_job_template_shift_start').toggle(@mealRelatedAndDateTime())
    @$('.form-group.work_job_template_shift_end').toggle(@mealRelatedAndDateTime())
    @$('.form-group.work_job_template_hours').toggle(!@mealRelatedAndDateTime())

  mealRelatedAndDateTime: ->
    @timeType() == 'date_time' && @mealRelated()

  timeType: ->
    @$('#work_job_template_time_type').val()

  mealRelated: ->
    @$('#work_job_template_meal_related').is(':checked')
