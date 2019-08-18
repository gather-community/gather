# Sets up AJAX-based select2 widgets based on data attributes.
Gather.Views.AjaxSelect2 = Backbone.View.extend
  initialize: (options) ->
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
    $select.select2
      ajax:
        url: $select.data('select2-src')
        dataType: 'json'
        delay: 250
        data: (params) => @buildGetParams(params, $select)
        processResults: (data, page) => @processResults(data, page, $select.data('select2-label-attr'))
        cache: true
      allowClear: $select.data('select2-allow-clear')
      createTag: @createTag
      language: inputTooShort: -> $select.data('select2-prompt')
      minimumInputLength: 1
      placeholder: $select.data('select2-placeholder')
      tags: $select.data('select2-tags')
      templateResult: @templateResult
      width: if !!$select.data('select2-variable-width') then null else '100%'

  buildGetParams: (params, $select) ->
    $.extend @options.extraData,
      search: params.term
      page: params.page
      context: $select.data('select2-context')

  # Transforms the data returned from the AJAX request into the format required by select2.
  processResults: (data, page, labelAttr) ->
    labelAttr ||= 'name'
    {
      results: data.results.map((u) -> {id: u.id, text: u[labelAttr]})
      pagination:
        more: data.meta && data.meta.more
    }

  # Adds a custom `newTag` key to the data object for a newly created list item.
  # Only applicable if `tags` is true.
  createTag: (params) ->
    term = $.trim(params.term)
    if term == ''
      null
    else
      {id: term, text: term, newTag: true}

  # Adds a [Create New] suffix in the result list if an item has newTag true.
  # Only applicable if `tags` is true.
  templateResult: (params) ->
    if params.newTag
      "#{params.text} [#{I18n.t('common.create_new')}]"
    else
      params.text
