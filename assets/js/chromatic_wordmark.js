let cleanup = () => {}

export function initChromaticWordmark() {
  cleanup()
  const wordmark = document.querySelector(".chromatic-wordmark")
  if (!wordmark) return
  const offsets = document.querySelectorAll("[data-chroma-offset]")
  const blurs = document.querySelectorAll("[data-chroma-blur]")
  const listeners = new AbortController()
  const options = {signal: listeners.signal, passive: true}
  const reducedMotion = matchMedia("(prefers-reduced-motion: reduce)")
  let frame = null, lastTime = 0
  let hovered = false, hoverBlend = 0

  function paint() {
    const split = 2 + 1.3 * hoverBlend
    for (const offset of offsets) {
      offset.setAttribute("dx", split * Number(offset.dataset.chromaOffset))
      offset.setAttribute("dy", 0)
    }
    for (const channel of blurs) {
      channel.setAttribute("stdDeviation", 0.1 * split / 3.5 * Number(channel.dataset.chromaBlur))
    }
    wordmark.setAttribute("data-chroma-active", "")
    wordmark.style.setProperty("--hover-tracking", `${0.05 * hoverBlend}em`)
  }

  function animate(time) {
    const elapsed = Math.min((time - lastTime) / 1000, 0.05)
    lastTime = time
    const target = hovered ? 1 : 0
    const rate = target ? 8 : 4
    hoverBlend += (target - hoverBlend) * (1 - Math.exp(-rate * elapsed))
    if (Math.abs(target - hoverBlend) < 0.001) hoverBlend = target
    const finished = hoverBlend === target
    paint()
    frame = finished ? null : requestAnimationFrame(animate)
  }

  function start() {
    if (frame !== null || reducedMotion.matches) return
    lastTime = performance.now()
    frame = requestAnimationFrame(animate)
  }

  function reset() {
    cancelAnimationFrame(frame)
    frame = null
    hovered = false
    hoverBlend = 0
    paint()
  }

  wordmark.addEventListener("pointerenter", event => {
    if (event.pointerType !== "mouse" || reducedMotion.matches) return
    hovered = true
    start()
  }, options)
  wordmark.addEventListener("pointerleave", event => {
    if (event.pointerType !== "mouse") return
    hovered = false
    start()
  }, options)
  window.addEventListener("blur", reset, options)
  document.addEventListener("visibilitychange", () => {
    if (document.hidden) reset()
  }, options)
  reducedMotion.addEventListener("change", reset, options)
  paint()
  cleanup = () => {
    listeners.abort()
    cancelAnimationFrame(frame)
    wordmark.removeAttribute("data-chroma-active")
    wordmark.style.removeProperty("--hover-tracking")
  }
}
