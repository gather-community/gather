# Sets up AJAX-based select2 widgets based on data attributes.
Gather.Views.AjaxSelect2 = Backbone.View.extend
  initialize: (options) ->
    self = this
    @options = options
    @options.extraData = @options.extraData || {}

    # Setup any select2 elements on the page at load.
    @setupSelect2sInside(@$el)

    # These events tells of an element in which there may be one or more select2 elements
    # that need to be picked up. We can assume that there are so already-setup select2s in them.
    @$el.on 'cocoon:after-insert', (e, container) => @setupSelect2sInside(@$(container))
    @$el.on 'gather:select2inserted', (e, container) => @setupSelect2sInside(@$(container))

  setupSelect2sInside: ($container) ->
    $container.find('select[data-select2-src]').each (_, el) => @setupSelect2(@$(el))

  setupSelect2: ($select) ->
    src = $select.data('select2-src')
    placeholder = $select.data('select2-placeholder')
    allowClear = $select.data('select2-allow-clear')
    labelAttr = $select.data('select2-label-attr') or 'name'
    variableWidth = !!$select.data('select2-variable-width')
    self = this
    $select.select2
      ajax:
        url: src
        dataType: 'json'
        delay: 250
        data: (params) ->
          $.extend self.options.extraData,
            search: params.term
            page: params.page
            context: $select.data('select2-context')
        processResults: (data, page) ->
          {
            results: data.results.map((u) -> {id: u.id, text: u[labelAttr]})
            pagination:
              more: data.meta.more
          }
        cache: true
      allowClear: allowClear
      language: inputTooShort: -> $select.data 'select2-prompt'
      minimumInputLength: 1
      placeholder: placeholder
      width: if variableWidth then null else '100%'
