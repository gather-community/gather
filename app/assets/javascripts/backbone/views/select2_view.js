Gather.Views.Select2View = Backbone.View.extend({

  initialize: function(options) {
    var self = this;
    this.options = options;
    this.options.extra_data = this.options.extra_data || {};

    this.$el.on('cocoon:after-insert', function(e, inserted) {
      self.setup_select2($(inserted).find("select[data-select2-src]"));
    });

    this.$('select[data-select2-src]').each(function() {
      self.setup_select2($(this));
    });
  },

  setup_select2: function(el) {
    var src = el.data("select2-src");
    var placeholder = el.data("select2-placeholder");
    var allowClear = el.data("select2-allow-clear");
    var label_attr = el.data("select2-label-attr") || "name";
    var variable_width = !!el.data("select2-variable-width");
    var self = this;

    el.select2({
      ajax: {
        url: "/" + src,
        dataType: 'json',
        delay: 250,
        data: function (params) {
          return $.extend(self.options.extra_data, {
            search: params.term,
            page: params.page,
            context: el.data("select2-context")
          });
        },
        processResults: function (data, page) {
          return {
            results: data.results.map(function(u){ return {id: u.id, text: u[label_attr]}; }),
            pagination: { more: data.meta.more }
          }
        },
        cache: true
      },
      allowClear: allowClear,
      language: {
        inputTooShort: function() {
          return el.data("select2-prompt");
        }
      },
      minimumInputLength: 1,
      placeholder: placeholder,
      width: variable_width ? null : '100%'
    });
  }
});
