export function initPhotoLightbox() {
  const trigger = document.querySelector("[data-photo-open]")
  const dialog = document.getElementById("photo-lightbox")
  if (!trigger || !dialog || trigger.dataset.initialized) return
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

  dialog.addEventListener("click", event => {
    if (event.target === dialog) dialog.close()
  })
}
