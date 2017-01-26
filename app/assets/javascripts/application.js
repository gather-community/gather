// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or any plugin's vendor/assets/javascripts directory can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file.
//
// Read Sprockets README (https://github.com/rails/sprockets#sprockets-directives) for details
// about supported directives.
//
//= require jquery
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
//= require cocoon
//= require underscore
//= require backbone
//= require backbone_rails_sync
//= require backbone_datalink
//= require backbone/mess
//= require_tree .

$(document).ready(function(){ $('form').preventDoubleSubmission(); });

Mess.TIME_FORMATS = {
  fullDatetime: 'ddd MMM D YYYY h:mm a',
  machineDatetime: 'YYYY-MM-DD HH:mm',
  regDate: 'ddd MMM D YYYY',
  regTime: 'h:mm a',
  compactDate: 'YYYY-MM-DD'
}
