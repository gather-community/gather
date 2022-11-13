Gather.Views.DirtyChecker = Backbone.View.extend({

  initialize(params) {
    params.helpers = params.helpers || [];
    params.helpers.push(this.datetimePickerHelper);
    params.helpers.push(this.hiddenInputHelper);
    this.$el.dirtyForms({helpers: params.helpers});
  },

  events: {
    "cocoon:after-insert": "rescan",
    "cocoon:after-remove": "rescan",
    "gather:select2inserted": "rescan"
  },

  rescan() {
    this.$el.dirtyForms("rescan");
  },

  // A helper that lets other code manually mark the form as dirty by adding the .dirty-flag class.
  customDirtyHelper: {
    isDirty($node) {
      if ($node.is("form")) {
        return $node.hasClass("dirty-flag");
      } else {
        return false;
      }
    },
    setClean($node) {
      if ($node.is("form")) {
        return $node.removeClass("dirty-flag");
      }
    }
  },

  // A helper that checks datetimepickers for dirtiness.
  datetimePickerHelper: {
    isDirty($node) {
      let dirty = false;
      $node.find(".input-group.datetimepicker").each(function() {
        const orig = moment($(this).find("input").data("initial-value"));
        const current = $(this).data("DateTimePicker").date();
        if ((orig && current && !orig.isSame(current)) || (!orig && !current)) {
          if ($.DirtyForms.debug) {
            console.warn("[DirtyFormDateTimePickerHelper] Found dirty picker ", this);
          }
          dirty = true;
          return false;
        }
      });
      return dirty;
    }
  },

  // Checks hidden inputs with the data-orig-val attribute to see if they have changed.
  hiddenInputHelper: {
    isDirty($node) {
      let dirty = false;
      $node.find("input[type=hidden][data-orig-val]").each(function() {
        console.log($(this).val());
        console.log($(this).data("orig-val"));
        if ($(this).val().toString() !== $(this).data("orig-val").toString()) {
          dirty = true;
          return false;
        }
      });
      return dirty;
    }
  }
});
