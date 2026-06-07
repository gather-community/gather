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
//= require serviceworker/companion
//= require_tree .
/* eslint-enable */

$(document).ready(function() {
  $("form").preventDoubleSubmission();
});
