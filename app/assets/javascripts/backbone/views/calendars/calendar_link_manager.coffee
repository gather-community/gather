Gather.Views.Calendars.CalendarLinkManager = Backbone.View.extend
  update: (viewType, date) ->
    qsParams = {view: viewType, date: date}
    @updatePermalink(qsParams)
    @updateOtherCalendarLinks(qsParams)

  updatePermalink: (qsParams) ->
    @updateLink(@$('#permalink'), qsParams)

  updateOtherCalendarLinks: (qsParams) ->
    @$('.calendar-link').each (_, el) => @updateLink(el, qsParams)

  updateLink: (link, qsParams) ->
    path = href = @$(link).attr('href')
    url = new URL(path, 'https://example.com')
    Object.keys(qsParams).forEach (k) -> url.searchParams.set(k, qsParams[k])
    path = url.href.replace('https://example.com', '')
    $(link).attr('href', path)
