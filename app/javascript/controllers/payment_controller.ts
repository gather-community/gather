import {Controller} from "@hotwired/stimulus";

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

  connect(): void {
    this.stripe = Stripe(this.publishableKeyValue);
    console.log(this.acssDebitModeValue);
    if (this.acssDebitModeValue) {
      this.showSubmitButton();
    } else {
      this.initPaymentElement();
    }
  }

  initPaymentElement(): void {
    const options = {clientSecret: this.clientSecretValue};
    this.elements = this.stripe.elements(options);
    const paymentElement = this.elements.create("payment", {
      fields: {billingDetails: {email: "never"}},
      /*
       * This is mainly to show us_bank_account first
       * Also card is likely to be more useful for communities than wallets, so we put that first.
       */
      paymentMethodOrder: ["us_bank_account", "card"]
    });
    paymentElement.on("ready", this.showSubmitButton.bind(this));
    paymentElement.mount("#payment-element");
  }

  showSubmitButton(): void {
    this.submitButtonTarget.classList.remove("hiding");
  }

  async handleSubmit(event: Event): Promise<T> {
    event.preventDefault();
    if (this.acssDebitModeValue) {
      this.handleAcssDebitSubmit();
    } else {
      this.handlePaymentElementSubmit();
    }
  }

  async handleAcssDebitSubmit(): Promise<T> {
    const accountHolder = this.formTarget["payment[accountholder_name]"].value.trim();

    if (accountHolder === "") {
      alert("Please specify the accountholder name.");
      return;
    }

    document.getElementById("glb-load-ind").classList.remove("hiding");
    const confirmFunction = this.clientSecretValue.startsWith("pi_") ?
      this.stripe.confirmAcssDebitPayment : this.stripe.confirmAcssDebitSetup;
    const {paymentIntent, error} = await confirmFunction(
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
    if (error) {
      document.getElementById("glb-load-ind").classList.add("hiding");
      console.log(error.message);
    } else {
      window.location.href = this.returnUrlValue;
    }
  }

  async handlePaymentElementSubmit(): Promise<T> {
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
