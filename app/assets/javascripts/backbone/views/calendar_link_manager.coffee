Gather.Views.CalendarLinkManager = Backbone.View.extend
  initialize: (options) ->
    @calendarView = options.calendarView
    @listenTo(@calendarView, 'viewRender', @onViewRender.bind(this))

  onViewRender: ->
    viewType = @calendarView.viewType()
    currentDate = @calendarView.currentDate()
    qsParams = "view=#{viewType}&date=#{currentDate}"
    @updatePermalink(qsParams)
    @updateOtherResourceLinks(qsParams)

  updatePermalink: (qsParams) ->
    @updateLink($('#permalink'), qsParams)

  updateOtherResourceLinks: (qsParams) ->
    @$('.resource-link').each (_, el) => @updateLink(el, qsParams)

  updateLink: (link, qsParams) ->
    href = $(link).attr('href').replace(/(resource_id=[^&]+).*$/, (_, $1) -> "#{$1}&#{qsParams}")
    $(link).attr('href', href)
