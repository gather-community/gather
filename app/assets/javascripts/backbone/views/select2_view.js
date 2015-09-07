Mess.Views.Select2View = Backbone.View.extend({

  initialize: function(options) {
    var self = this;

    this.$el.on('cocoon:after-insert', function(e, inserted) {
      console.log("after insert")
      self.setup_select2($(inserted).find("select[data-select2-src]"));
    });

    this.$('select[data-select2-src]').each(function(){
      self.setup_select2($(this));
    });
  },

  setup_select2: function(el) {
    el.select2({
      ajax: {
        url: "/users",
        dataType: 'json',
        delay: 250,
        data: function (params) {
          return {
            search: params.term,
            page: params.page
          };
        },
        processResults: function (data, page) {
          console.log(data);
          return {
            results: data.users.map(function(u){ return {id: u.id, text: u.name}; }),
            pagination: { more: data.meta.more }
          }
        },
        cache: true
      },
      language: {
        inputTooShort: function() {
          return "Please type a few letters of the " + "user" + "'s name."
        }
      },
      minimumInputLength: 1,
    });
  }
});
