import { Controller } from "@hotwired/stimulus"

// Toggles labels/hints and manages textarea content (pre-fill + saved values) per decision.
export default class extends Controller {
  static targets = ["hint", "label"]
  static values = { contactFirstName: String, communityName: String, approverFirstName: String }

  declare readonly hintTargets: HTMLElement[]
  declare readonly labelTargets: HTMLElement[]
  declare readonly contactFirstNameValue: string
  declare readonly communityNameValue: string
  declare readonly approverFirstNameValue: string

  private savedValues: Record<string, string> = {}
  private currentDecision = ""

  connect() {
    this.update()
  }

  update() {
    const select = this.element.querySelector("select") as HTMLSelectElement | null
    if (!select) return
    const decision = select.value

    const textarea = this.element.querySelector("textarea") as HTMLTextAreaElement | null
    if (!textarea) return

    if (this.currentDecision !== decision) {
      if (this.currentDecision) {
        this.savedValues[this.currentDecision] = textarea.value
      }
      textarea.value = decision in this.savedValues
        ? this.savedValues[decision]
        : this.defaultValue(decision)
      this.currentDecision = decision
    }

    this.hintTargets.forEach((hint) => { hint.hidden = hint.dataset.decision !== decision })
    this.labelTargets.forEach((label) => { label.hidden = label.dataset.decision !== decision })
  }

  private defaultValue(decision: string): string {
    if (decision === "approve") {
      return [
        `Dear ${this.contactFirstNameValue},`,
        "",
        `Great news! Your application to join Gather for the community "${this.communityNameValue}" has been approved.`,
        "",
        "#######################################",
        "ENTER A PERSONALIZED NOTE HERE, MENTION",
        "SOMETHING SPECIFIC ABOUT THE COMMUNITY",
        "#######################################",
        "",
        "We're setting up your community now. You'll receive a separate email shortly with instructions to sign in for the first time.",
        "",
        "Welcome aboard!",
        "",
        `${this.approverFirstNameValue} for the Gather Team`,
      ].join("\n")
    }
    return ""
  }
}
