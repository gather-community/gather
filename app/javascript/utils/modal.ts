import {application} from "../controllers/application";
import i18n from "./i18n";
import type ModalController from "../controllers/modal_controller";
import type {ModalOptions, ModalResult} from "../controllers/modal_controller";

// Locates the singleton modal controller rendered in the layout (layouts/_modal.html.erb).
const modalController = (): ModalController => {
  const element = document.querySelector("[data-controller~=\"modal\"]");
  if (!element) {
    throw new Error("Modal element not found; is layouts/_modal rendered?");
  }
  const controller = application.getControllerForElementAndIdentifier(element, "modal");
  if (!controller) {
    throw new Error("Modal controller not connected yet.");
  }
  return controller as ModalController;
};

// Core entry point. Returns the clicked button's index (or -1 for X/overlay/Esc) plus any input.
export const showModal = (options: ModalOptions): Promise<ModalResult> => modalController().open(options);

interface AlertOptions {
  title?: string;
  label?: string;
}
export const alertModal = (content: string, options: AlertOptions = {}): Promise<void> => showModal({
  title: options.title || i18n.t("modal.alert_title"),
  content,
  buttons: [{label: options.label || i18n.t("modal.ok"), variant: "primary"}],
}).then(() => undefined);

interface ConfirmOptions {
  title?: string;
  confirmLabel?: string;
  cancelLabel?: string;
  confirmVariant?: "primary" | "default" | "danger";
}
// Resolves true only when the confirm (final) button is clicked; X/overlay/Esc/Cancel → false.
export const confirmModal = (content: string, options: ConfirmOptions = {}): Promise<boolean> => showModal({
  title: options.title || i18n.t("modal.confirm_title"),
  content,
  buttons: [
    {label: options.cancelLabel || i18n.t("modal.cancel"), variant: "default"},
    {label: options.confirmLabel || i18n.t("modal.ok"), variant: options.confirmVariant || "primary"},
  ],
}).then((result) => result.index === 1);

interface PromptOptions extends Omit<ConfirmOptions, "title"> {
  title: string; // Required — the caller must supply a prompt title
  value?: string;
  placeholder?: string;
}
// Resolves the entered string on confirm, or null on any dismissal.
export const promptModal = (
  content: string,
  options: PromptOptions
): Promise<string | null> => showModal({
  title: options.title,
  content,
  input: {value: options.value, placeholder: options.placeholder},
  buttons: [
    {label: options.cancelLabel || i18n.t("modal.cancel"), variant: "default"},
    {label: options.confirmLabel || i18n.t("modal.ok"), variant: options.confirmVariant || "primary"},
  ],
}).then((result) => (result.index === 1 ? (result.value ?? "") : null));

// Expose for the Backbone/legacy sprockets bundle (mirrors how utils/i18n.ts sets window.I18n).
(window as any).Modal = {showModal, alertModal, confirmModal, promptModal};
