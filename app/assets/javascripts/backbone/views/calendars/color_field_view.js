Gather.Views.Calendars.ColorFieldView = Backbone.View.extend({
  initialize(params) {
    this.textBox = this.$("input[type=text]");
    this.update();
  },

  events: {
    "keyup input[type=text]": "update",
    "click .swatch": "pickColor"
  },

  update() {
    const value = this.textBox.val();
    const color = value.match(/^#[0-9a-f]{6}$/) ? value : "#999999";
    this.textBox.css("background-color", color);
  },

  pickColor(event) {
    this.textBox.val(this.$(event.currentTarget).data("color"));
    this.textBox.trigger("keyup");
  }
});
