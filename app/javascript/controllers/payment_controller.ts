import { Controller } from "@hotwired/stimulus";
import { loadStripe, Stripe, StripeElements } from "@stripe/stripe-js";

export default class extends Controller<HTMLFormElement> {
  static values = {
    publishableKey: String,
    clientSecret: String,
    contactEmail: String,
    returnUrl: String,
    acssDebitMode: Boolean,
  };
  static targets = ["submitButton", "form"];

  declare publishableKeyValue: string;
  declare clientSecretValue: string;
  declare contactEmailValue: string;
  declare returnUrlValue: string;
  declare acssDebitModeValue: boolean;
  declare submitButtonTarget: HTMLElement;
  declare formTarget: HTMLFormElement;

  stripe: Stripe | null = null;
  elements: StripeElements | null = null;

  async connect(): Promise<void> {
    this.stripe = await loadStripe(this.publishableKeyValue);
    if (!this.stripe) {
      console.error("Stripe failed to initialize");
      return;
    }
    console.log(this.acssDebitModeValue)

    if (this.acssDebitModeValue) {
      this.showSubmitButton();
    } else {
      this.initPaymentElement();
    }
  }

  initPaymentElement(): void {
    if (!this.stripe) return;

    const options = { clientSecret: this.clientSecretValue };
    this.elements = this.stripe.elements(options);

    const paymentElement = this.elements.create("payment", {
      fields: { billingDetails: { email: "never" } },
      // This is mainly to show us_bank_account first
      // Also card is likely to be more useful for communities than wallets, so we put that first.
      paymentMethodOrder: ["us_bank_account", "card"],
    });

    paymentElement.on("ready", this.showSubmitButton.bind(this));
    paymentElement.mount("#payment-element");
  }

  showSubmitButton(): void {
    this.submitButtonTarget.classList.remove("hiding");
  }

  async handleSubmit(event: Event): Promise<void> {
    event.preventDefault();
    if (this.acssDebitModeValue) {
      await this.handleAcssDebitSubmit();
    } else {
      await this.handlePaymentElementSubmit();
    }
  }

  async handleAcssDebitSubmit(): Promise<void> {
    const accountHolder = this.formTarget['payment[accountholder_name]'].value.trim();

    if (accountHolder === '') {
      alert('Please specify the accountholder name.');
      return;
    }

    document.getElementById('glb-load-ind')?.classList.remove('hiding');
    const confirmFunction = this.clientSecretValue.startsWith("pi_") ?
      this.stripe.confirmAcssDebitPayment : this.stripe.confirmAcssDebitSetup;
      
    const result = await confirmFunction(
      this.clientSecretValue,
      {
        payment_method: {
          billing_details: {
            name: accountHolder,
            email: this.contactEmailValue,
          },
        },
      }
    );

    if (result.error) {
      document.getElementById('glb-load-ind')?.classList.add('hiding');
      console.log(result.error.message);
    } else if ("paymentIntent" in result) {
      // It's a PaymentIntentResult
      window.location.href = this.returnUrlValue;
    } else {
      console.error("Unexpected result", result);
    }
  }

  async handlePaymentElementSubmit(): Promise<void> {
    if (!this.stripe || !this.elements) return;

    const confirmFunction = this.clientSecretValue.startsWith("pi_")
      ? this.stripe.confirmPayment
      : this.stripe.confirmSetup;

    try {
      const result = await confirmFunction({
        elements: this.elements,
        confirmParams: {
          return_url: this.returnUrlValue,
          payment_method_data: { billing_details: { email: this.contactEmailValue } },
        },
      });

      if (result.error) {
        console.error(result.error.message);
      }
    } catch (err) {
      console.error(err);
    }
  }
}