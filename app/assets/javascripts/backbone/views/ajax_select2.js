// Sets up AJAX-based select2 widgets based on data attributes.
Gather.Views.AjaxSelect2 = Backbone.View.extend({
  initialize(options) {
    this.options = options;
    this.options.extraData = this.options.extraData || {};

    // Setup any select2 elements on the page at load.
    this.setupSelect2sInside(this.$el);

    /*
     * These events tells of an element in which there may be one or more select2 elements
     * that need to be picked up. We can assume that there are so already-setup select2s in them.
     */
    this.$el.on("cocoon:after-insert", (e, container) => this.setupSelect2sInside(this.$(container)));
    this.$el.on("gather:select2inserted", (e, container) => this.setupSelect2sInside(this.$(container)));
  },

  setupSelect2sInside($container) {
    $container.find("select[data-select2-src]").each((_, el) => this.setupSelect2(this.$(el)));
  },

  setupSelect2($select) {
    $select.select2({
      ajax: {
        url: $select.data("select2-src"),
        dataType: "json",
        delay: 250,
        data: params => this.buildGetParams(params, $select),
        processResults: (data, page) => this.processResults(data, page, $select.data("select2-label-attr")),
        cache: true
      },
      allowClear: $select.data("select2-allow-clear"),
      createTag: this.createTag,
      language: {inputTooShort() {
        return $select.data("select2-prompt");
      }},
      minimumInputLength: 1,
      placeholder: $select.data("select2-placeholder"),
      tags: $select.data("select2-tags"),
      templateResult: this.templateResult,
      width: $select.data("select2-variable-width") ? null : "100%"
    });
  },

  buildGetParams(params, $select) {
    /*
     * If extraData is a function, call it.
     * If extraData is an array, JSONify it and make an object.
     */
    let {
      extraData
    } = this.options;
    if (typeof (extraData) === "function") {
      extraData = extraData.call();
    }
    if (extraData instanceof Array) {
      extraData = {data: JSON.stringify(extraData)};
    }
    return $.extend(extraData, {
      search: params.term,
      page: params.page,
      context: $select.data("select2-context")
    });
  },

  // Transforms the data returned from the AJAX request into the format required by select2.
  processResults(data, page, labelAttr) {
    if (!labelAttr) {
      labelAttr = "name";
    }
    return {
      results: data.results.map(u => ({
        id: u.id,
        text: u[labelAttr]
      })),
      pagination: {
        more: data.meta && data.meta.more
      }
    };
  },

  /*
   * Adds a custom `newTag` key to the data object for a newly created list item.
   * Only applicable if `tags` is true.
   */
  createTag(params) {
    const term = $.trim(params.term);
    if (term === "") {
      return null;
    } else {
      return {id: term, text: term, newTag: true};
    }
  },

  /*
   * Adds a [Create New] suffix in the result list if an item has newTag true.
   * Only applicable if `tags` is true.
   */
  templateResult(params) {
    if (params.newTag) {
      return `${params.text} [${I18n.t("common.create_new")}]`;
    } else {
      return params.text;
    }
  }
});
