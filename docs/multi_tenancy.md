# Notes on Multi Tenancy

The idea is to have multiple lines of defense against data leakage:

Things that restrict access to a page

1. Subdomain validity check
2. Authentication (Devise)
3. Community ‘show’ permission check
4. Authorization (Pundit)
  5. Record-based
  6. Class-based*
5. acts_as_tenant

Note that authorization checks what a user can _ever_ access, while acts_as_tenant checks what they can access given the current tenant scope.

## Class-based Authorization

Class-based authorization, e.g. `MealPolicy.new(user, Meal)` instead of `MealPolicy.new(user, @meal)`, should be avoided where possible. It is better to use a dummy object, e.g. `MealPolicy.new(user, Meal.new(community: current_community))` so that the policy class can opt to check the record's community if it wants to.

Policies must explicitly enable class based authorization by overriding `allow_class_based_auth` to return true. If this is not done and class based auth is attempted, the Policy may raise an error.
