# frozen_string_literal: true

module Meals
  # Models the presentation of a summary of a meal.
  class Summary < ApplicationDecorator
    delegate_all

    def reimbursement?
      community.settings.meals.reimb_instructions.present? || show_reimb_form?
    end

    def formatted_reimb_instructions
      h.safe_render_markdown(community.settings.meals.reimb_instructions)
    end

    def show_reimb_form?
      community.settings.meals.show_reimb_form?
    end
  end
end
