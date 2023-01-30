import { Controller } from "@hotwired/stimulus";

export default class extends Controller<HTMLFormElement> {
  static values = {
    publishableKey: String,
    clientSecret: String,
    contactEmail: String,
    returnUrl: String
  };
  static targets = ['submitButton'];

  declare publishableKeyValue: string;
  declare clientSecretValue: string;
  declare contactEmailValue: string;
  declare returnUrlValue: string;
  declare submitButtonTarget: HTMLElement;

  connect(): void {
    this.stripe = Stripe(this.publishableKeyValue);
    const options = {
      clientSecret: this.clientSecretValue,
    };

    // Set up Stripe.js and Elements to use in checkout form, passing the client secret obtained in step 5
    this.elements = this.stripe.elements(options);

    // Create and mount the Payment Element
    const paymentElement = this.elements.create('payment', {fields: {billingDetails: {email: 'never'}}});
    paymentElement.on('ready', this.handleReady.bind(this));
    paymentElement.mount('#payment-element');
  }

  handleReady(): void {
    this.submitButtonTarget.classList.remove('hiding');
  }

  async confirm(): Promise<T> {
    const confirmFunction = this.clientSecretValue.startsWith("pi_") ?
      this.stripe.confirmPayment : this.stripe.confirmSetup;
    await confirmFunction({
      elements: this.elements,
      confirmParams: {
        return_url: this.returnUrlValue,
        payment_method_data: {
          billing_details: {
            email: this.contactEmailValue
          }
        }
      }
    });
  }
}
