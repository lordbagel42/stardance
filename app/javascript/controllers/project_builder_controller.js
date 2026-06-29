import { Controller } from "@hotwired/stimulus";

// Reveals the hardware stage chooser on /projects/new.
// Level 1: "I need Funding" (submits directly) | "I don't need Funding" (reveals level 2)
// Level 2: "I'm still designing" | "I'm ready to build"
export default class extends Controller {
  static targets = ["chooser", "hardwareBtn", "subChooser", "noFundingBtn"];

  toggle() {
    const open = !this.chooserTarget.classList.contains("is-open");
    this.chooserTarget.classList.toggle("is-open", open);
    this.chooserTarget.inert = !open;

    if (this.hasHardwareBtnTarget) {
      this.hardwareBtnTarget.setAttribute("aria-expanded", String(open));
    }

    // Collapse sub-chooser when the top-level chooser is closed
    if (!open && this.hasSubChooserTarget) {
      this._closeSubChooser();
    }
  }

  showNoFundingOptions(event) {
    event.preventDefault();
    if (!this.hasSubChooserTarget) return;

    const open = !this.subChooserTarget.classList.contains("is-open");
    this.subChooserTarget.classList.toggle("is-open", open);
    this.subChooserTarget.inert = !open;

    if (this.hasNoFundingBtnTarget) {
      this.noFundingBtnTarget.setAttribute("aria-expanded", String(open));
    }
  }

  _closeSubChooser() {
    this.subChooserTarget.classList.remove("is-open");
    this.subChooserTarget.inert = true;
    if (this.hasNoFundingBtnTarget) {
      this.noFundingBtnTarget.setAttribute("aria-expanded", "false");
    }
  }
}
