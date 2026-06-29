import { Controller } from "@hotwired/stimulus";

// Reveals the Design/Build stage chooser on /projects/new when the user clicks
// "New hardware project +". The collapsed chooser is marked inert so its
// controls drop out of the tab order; a CSS grid-rows transition animates the reveal.
export default class extends Controller {
  static targets = ["chooser", "hardwareBtn"];

  toggle() {
    const open = !this.chooserTarget.classList.contains("is-open");
    this.chooserTarget.classList.toggle("is-open", open);
    this.chooserTarget.inert = !open;

    if (this.hasHardwareBtnTarget) {
      this.hardwareBtnTarget.setAttribute("aria-expanded", String(open));
    }
  }
}
