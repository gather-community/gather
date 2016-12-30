Mess.Views.Select2View = Backbone.View.extend({

  initialize: function(options) {
    var self = this;
    this.options = options;
    this.options.extra_data = this.options.extra_data || {};

    this.$el.on('cocoon:after-insert', function(e, inserted) {
      console.log("after insert")
      self.setup_select2($(inserted).find("select[data-select2-src]"));
    });

    this.$('select[data-select2-src]').each(function(){
      self.setup_select2($(this));
    });
  },

  setup_select2: function(el) {
    var src = el.data("select2-src");
    var label_attr = el.data("select2-label-attr") || "name";
    var self = this;
    var params = el.data("select2-request-params");
    params = params ? "?" + params : "";

    el.select2({
      ajax: {
        url: "/" + src + params,
        dataType: 'json',
        delay: 250,
        data: function (params) {
          return $.extend(self.options.extra_data, {
            search: params.term,
            page: params.page
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
      language: {
        inputTooShort: function() {
          return el.data("select2-prompt");
        }
      },
      minimumInputLength: 1,
      width: '100%'
    });
  }
});
