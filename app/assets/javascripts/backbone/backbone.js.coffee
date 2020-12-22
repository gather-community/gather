#= require_self

# Must be loaded early due to inheritance
#= require ./views/print_view

#= require_tree ./templates
#= require_tree ./models
#= require_tree ./views
#= require_tree ./routers

window.Gather =
  Models: {}
  Collections: {}
  Routers: {}
  Views:
    Meals: {}
    People: {}
    Work: {}
    Reservations: {}
    Groups: {}
    Billing: {}
