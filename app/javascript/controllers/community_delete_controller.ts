import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { slug: String, url: String }

  declare readonly slugValue: string
  declare readonly urlValue: string

  confirm(event: Event) {
    event.preventDefault()
    event.stopImmediatePropagation()

    const typed = window.prompt(`To permanently delete this community, type its slug:\n"${this.slugValue}"`)
    if (typed !== this.slugValue) return

    const form = document.createElement("form")
    form.method = "post"
    form.action = this.urlValue

    this.appendHidden(form, "_method", "delete")
    this.appendHidden(form, "community_slug", typed)

    const csrfMeta = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')
    if (csrfMeta) this.appendHidden(form, "authenticity_token", csrfMeta.content)

    document.body.appendChild(form)
    form.submit()
  }

  private appendHidden(form: HTMLFormElement, name: string, value: string) {
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = name
    input.value = value
    form.appendChild(input)
  }
}
