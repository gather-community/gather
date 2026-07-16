import {Controller} from "@hotwired/stimulus";
import {loadStripe, Stripe, StripeElements, StripeAddressElement} from "@stripe/stripe-js";

// Mounts the Stripe Address Element to collect the billing address for a self-serve subscription,
// restricted to the countries Gather can bill in. There's no PaymentIntent yet at this step (that
// comes after the subscription is created), so we build Elements in stand-alone address mode and
// mirror the collected fields into hidden inputs the plain Rails form submits.
export default class extends Controller<HTMLFormElement> {
  static values = {
    publishableKey: String,
    allowedCountries: Array,
    submitLabel: String,
  };
  static targets = ["mount", "submit", "field"];

  declare publishableKeyValue: string;
  declare allowedCountriesValue: string[];
  declare submitLabelValue: string;
  declare mountTarget: HTMLElement;
  declare submitTarget: HTMLButtonElement;
  declare fieldTargets: HTMLInputElement[]; // hidden inputs named address_line1, address_city, ...

  stripe: Stripe | null = null;
  elements: StripeElements | null = null;
  addressElement: StripeAddressElement | null = null;

  async connect(): Promise<void> {
    this.stripe = await loadStripe(this.publishableKeyValue);
    if (!this.stripe) {
      console.error("Stripe failed to initialize");
      return;
    }
    this.elements = this.stripe.elements();
    this.addressElement = this.elements.create("address", {
      mode: "billing",
      allowedCountries: this.allowedCountriesValue,
    });
    this.addressElement.on("change", (event) => this.syncFields(event));
    this.addressElement.mount(this.mountTarget);
  }

  // Copy the Address Element's current value into the hidden inputs, and only enable submission once
  // the address is complete so we never post a half-filled address.
  syncFields(event: {complete: boolean; value: {address: Record<string, string>}}): void {
    const a = event.value.address;
    const map: Record<string, string | undefined> = {
      address_line1: a.line1,
      address_line2: a.line2,
      address_city: a.city,
      address_state: a.state,
      address_postal_code: a.postal_code,
      address_country: a.country,
    };
    this.fieldTargets.forEach((input) => {
      input.value = map[input.dataset.addressField ?? ""] ?? "";
    });
    this.submitTarget.disabled = !event.complete;
  }

  disconnect(): void {
    this.addressElement?.destroy();
  }
}
