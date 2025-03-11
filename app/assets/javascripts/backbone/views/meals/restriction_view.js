Gather.Views.Meals.RestrictionView = Backbone.View.extend({

  initialize(options) {
  },

  events: {
    "click input[type=checkbox]": "changeDisabled",
  },

  changeDisabled(e) {
    const curCb = $(e.currentTarget);
    var opposite = curCb.val() == true ? false : true 
    curCb.val(opposite);
    var absence_id = "#" + curCb[0].id.replace("deactivated_at", "absence")
    var contains_id = "#" + curCb[0].id.replace("deactivated_at", "contains")

    if(curCb.is(':checked')) {
      curCb.val(new Date().toLocaleString());
      $(absence_id).attr("disabled", "disabled");
      $(contains_id).attr("disabled", "disabled");

    } else {
      $(absence_id).removeAttr("disabled");
      $(contains_id).removeAttr("disabled");
    }
  }
});
