// NanoPet care reactions: flash the pet's reaction class and clear it when
// the CSS animation finishes, so the bounce/spin/sleep plays again on every
// care action without a full page reload.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]

  connect() {
    this.panelTarget.addEventListener("animationend", (event) => {
      if (event.animationName.startsWith("np-")) {
        this.panelTarget.classList.remove("nano-pet--feed", "nano-pet--play", "nano-pet--rest", "nano-pet--rescue")
      }
    })
  }
}
