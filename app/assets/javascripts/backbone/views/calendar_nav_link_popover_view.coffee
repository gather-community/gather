Gather.Views.CalendarNavLinkPopoverView = Backbone.View.extend
  initialize: ->
    @showPopover(@$('.navbar.hidden-xs a[href^="/calendars/events"]'))

  events:
    'click a[href="#dismisspopover"]': 'dismissLinkClicked'
    'shown.bs.collapse': 'navbarShown'

  navbarShown: (e) ->
    return if @dismissed
    @showPopover(@$(e.target).find('a.dropdown-toggle > i.fa-calendar'))

  showPopover: ($el) ->
    $el.popover
      content: '<div><b>Reservations</b> is now called <b>Calendars</b>! ' +
        'Check it out!</div><div><a href="#dismisspopover">Dismiss</a></div>'
      html: true
      placement: 'bottom'
      trigger: 'manual'
    $el.popover('show')

  dismissLinkClicked: (e) ->
    e.preventDefault()
    e.stopPropagation()
    @dismissed = true
    @$(e.target).closest('.popover').popover('hide')
    $.ajax
      url: '/users/update-setting'
      method: 'PATCH'
      data:
        settings:
          calendar_popover_dismissed: 1
