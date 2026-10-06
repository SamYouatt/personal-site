export function initPhotoLightbox() {
  const triggers = [...document.querySelectorAll("[data-photo-open]")]
  triggers.forEach((trigger, index) => {
    const dialog = document.getElementById(trigger.dataset.photoOpen)
    if (!dialog || trigger.dataset.initialized) return
    trigger.dataset.initialized = "true"
    const image = dialog.querySelector("img")
    let previousOverflow

    trigger.addEventListener("click", event => {
      if (event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
      event.preventDefault()
      image.src = image.dataset.src
      previousOverflow = document.documentElement.style.overflow
      document.documentElement.style.overflow = "hidden"
      dialog.showModal()
    })

    dialog.addEventListener("close", () => {
      document.documentElement.style.overflow = previousOverflow
      trigger.focus({preventScroll: true})
    })

    dialog.addEventListener("keydown", event => {
      if (!dialog.open || event.altKey || event.ctrlKey || event.metaKey || event.shiftKey) return
      if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") return
      event.preventDefault()
      const next = triggers[index + (event.key === "ArrowRight" ? 1 : -1)]
      if (!next) return
      // Wait for close cleanup before opening the next dialog and locking scroll again.
      dialog.addEventListener("close", () => next.click(), {once: true})
      dialog.close()
    })

    dialog.addEventListener("click", event => {
      if (event.target === dialog) dialog.close()
    })
  })
}
