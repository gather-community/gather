/* eslint-disable */
//= require jquery2
//= require jquery_ujs
//= require bootstrap-sprockets
//= require moment
//= require bootstrap-datetimepicker
//= require pickers
//= require select2
//= require moment
//= require jquery-ui
//= require d3
//= require nv.d3
//= require fullcalendar
//= require dropzone
//= require prevent-double-submission
//= require jquery.dirtyforms
//= require jquery.waitforimages
//= require cocoon
//= require underscore
//= require backbone
//= require backbone_rails_sync
//= require backbone_datalink
//= require backbone/backbone
//= require i18n
//= require i18n/translations
//= require serviceworker/companion
//= require_tree .
/* eslint-enable */

$(document).ready(function() {
  $("form").preventDoubleSubmission();
});

Gather.TIME_FORMATS = {
  fullDatetime: "ddd MMM D YYYY h:mm a",
  machineDatetime: "YYYY-MM-DD HH:mm",
  regDate: "ddd MMM DD YYYY",
  regTime: "h:mm a",
  compactDate: "YYYY-MM-DD"
};
