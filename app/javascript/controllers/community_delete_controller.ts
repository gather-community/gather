import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { slug: String }

  declare readonly slugValue: string

  confirm(event: Event) {
    const typed = window.prompt(`To permanently delete this community, type its slug:\n"${this.slugValue}"`)
    if (typed !== this.slugValue) {
      event.preventDefault()
      event.stopImmediatePropagation()
    }
  }
}
