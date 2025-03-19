Gather.Views.Meals.RestrictionView = Backbone.View.extend({

  initialize(options) {
  },

  events: {
    "click input[type=checkbox]": "changeDisabled",
  },

  changeDisabled(e) {
    const curCb = $(e.currentTarget);
    var absence_id = "#" + curCb[0].id.replace("deactivated", "absence")
    var contains_id = "#" + curCb[0].id.replace("deactivated", "contains")

    if(curCb.is(':checked')) {
      $(absence_id).attr("disabled", "disabled");
      $(contains_id).attr("disabled", "disabled");

    } else {
      $(absence_id).removeAttr("disabled");
      $(contains_id).removeAttr("disabled");
    }
  }
});
