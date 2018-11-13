# Sets up AJAX-based select2 widgets based on data attributes.
Gather.Views.AjaxSelect2 = Backbone.View.extend
  initialize: (options) ->
    self = this
    @options = options
    @options.extraData = @options.extraData or {}

    @$el.on 'cocoon:after-insert', (e, inserted) ->
      self.setup_select2($(inserted).find('select[data-select2-src]'))

    @$('select[data-select2-src]').each ->
      self.setup_select2(self.$(this))

  setup_select2: (el) ->
    src = el.data('select2-src')
    placeholder = el.data('select2-placeholder')
    allowClear = el.data('select2-allow-clear')
    labelAttr = el.data('select2-label-attr') or 'name'
    variableWidth = !!el.data('select2-variable-width')
    self = this
    el.select2
      ajax:
        url: "/#{src}"
        dataType: 'json'
        delay: 250
        data: (params) ->
          $.extend self.options.extraData,
            search: params.term
            page: params.page
            context: el.data('select2-context')
        processResults: (data, page) ->
          {
            results: data.results.map((u) -> {id: u.id, text: u[labelAttr]})
            pagination:
              more: data.meta.more
          }
        cache: true
      allowClear: allowClear
      language: inputTooShort: -> el.data 'select2-prompt'
      minimumInputLength: 1
      placeholder: placeholder
      width: if variableWidth then null else '100%'
