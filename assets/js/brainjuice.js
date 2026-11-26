const soundNames = [
  "pad-press", "pad-release", "pill-press", "pill-release", "detent",
  "cart-seat", "cart-eject", "book-open", "book-close", "page-1", "page-2", "page-3",
  "tape-play", "tape-stop", "tape-loop",
]

const volumes = {
  "pad-press": 0.9,
  "pad-release": 0.6,
  "pill-press": 0.7,
  "pill-release": 0.45,
  "detent": 0.55,
  "cart-seat": 0.9,
  "cart-eject": 0.7,
  "book-open": 0.6,
  "book-close": 0.6,
  "page-1": 0.45,
  "page-2": 0.45,
  "page-3": 0.45,
  "tape-play": 0.45,
  "tape-stop": 0.45,
}

const tapeLoop = {start: 0.2, end: 2.2, volume: 0.16}
const detentSpacing = 0.045

let audio = null
let speaker = null
let buffers = {}
let soundsLoading = null
let soundsListening = false
let pressedKind = null

function loadSounds() {
  audio ??= new AudioContext()

  if (!speaker) {
    speaker = audio.createGain()
    speaker.gain.value = 0.7
    speaker.connect(audio.destination)
  }

  soundsLoading ??= Promise.all(soundNames.map(async name => {
    const response = await fetch(`/sounds/${name}.mp3`)
    buffers[name] = await audio.decodeAudioData(await response.arrayBuffer())
  }))

  return soundsLoading
}

function wakeAudio() {
  loadSounds()
  if (audio.state === "suspended") audio.resume()
}

function playSound(name, delay = 0) {
  wakeAudio()

  const buffer = buffers[name]
  if (!buffer) return

  const source = audio.createBufferSource()
  source.buffer = buffer

  const level = audio.createGain()
  level.gain.value = volumes[name]

  source.connect(level).connect(speaker)
  source.start(audio.currentTime + delay)
}

function playDetents(dial, target) {
  const active = dial.closest(".bj-knob-dial").querySelector(".bj-knob-tick.is-active")
  const from = Number(active.getAttribute("phx-value-index"))
  const to = Number(target.getAttribute("phx-value-index"))
  const detents = Math.max(1, Math.abs(to - from))

  for (let i = 0; i < detents; i++) playSound("detent", i * detentSpacing)
}

function press(control) {
  const kind = control.dataset.sound

  if (kind === "knob") playDetents(control, control)
  else if (kind === "cart") playSound("cart-seat")
  else {
    playSound(`${kind}-press`)
    pressedKind = kind
  }
}

function release() {
  if (!pressedKind) return
  playSound(`${pressedKind}-release`)
  pressedKind = null
}

export function initConsoleSounds() {
  if (!document.querySelector(".bj-desk")) return
  loadSounds()

  if (soundsListening) return
  soundsListening = true

  const soundingControl = event => {
    const control = event.target.closest("[data-sound]")
    return control && !control.disabled ? control : null
  }

  document.addEventListener("pointerdown", event => {
    const control = event.button === 0 && soundingControl(event)
    if (control) press(control)
  })

  document.addEventListener("pointerup", release)
  document.addEventListener("pointercancel", release)

  document.addEventListener("click", event => {
    const fromKeyboard = event.detail === 0
    const control = fromKeyboard && soundingControl(event)
    if (!control) return

    press(control)
    setTimeout(release, 70)
  })
}

export const SpeedDial = {
  mounted() {
    this.knob = this.el.querySelector("#speed-knob")

    this.knob.addEventListener("pointerdown", event => this.grab(event))
    this.knob.addEventListener("pointermove", event => this.turn(event))
    this.knob.addEventListener("pointerup", () => this.release())
    this.knob.addEventListener("pointercancel", () => this.release())

    this.el.addEventListener("click", event => {
      if (this.turned) {
        event.stopPropagation()
        this.turned = false
        return
      }

      if (event.target.closest("#speed-knob")) playSound("detent")
    }, true)
  },

  ticks() {
    return [...this.el.querySelectorAll(".bj-knob-tick")]
  },

  currentIndex() {
    return this.ticks().findIndex(tick => tick.classList.contains("is-active"))
  },

  grab(event) {
    if (event.button !== 0) return

    this.knob.setPointerCapture(event.pointerId)
    this.index = this.currentIndex()
    this.grabbed = {x: event.clientX, y: event.clientY}
    this.knobAngle = this.tickAngles()[this.index]
    this.pointerAngle = this.angleOf(event)
    this.turned = false
  },

  turn(event) {
    if (!this.grabbed) return

    const moved = Math.hypot(event.clientX - this.grabbed.x, event.clientY - this.grabbed.y)
    if (moved > 4) this.turned = true

    const pointerAngle = this.angleOf(event)
    if (pointerAngle === null) return

    if (this.pointerAngle !== null) {
      const turnedBy = ((pointerAngle - this.pointerAngle + 540) % 360) - 180
      this.knobAngle = Math.max(-135, Math.min(135, this.knobAngle + turnedBy))
    }
    this.pointerAngle = pointerAngle

    const tickAngles = this.tickAngles()
    const distances = tickAngles.map(angle => Math.abs(angle - this.knobAngle))
    const index = distances.indexOf(Math.min(...distances))
    if (index === this.index) return

    for (let i = 0; i < Math.abs(index - this.index); i++) playSound("detent", i * detentSpacing)

    this.el.style.setProperty("--angle", `${tickAngles[index]}deg`)
    this.pushEvent("set_speed", {index: String(index)})
    this.index = index
  },

  release() {
    this.grabbed = null
  },

  tickAngles() {
    return this.ticks().map(tick => parseFloat(tick.style.getPropertyValue("--angle")))
  },

  angleOf(event) {
    const knob = this.knob.getBoundingClientRect()
    const dx = event.clientX - (knob.left + knob.width / 2)
    const dy = event.clientY - (knob.top + knob.height / 2)

    const tooCloseToCentre = Math.hypot(dx, dy) < knob.width / 6
    if (tooCloseToCentre) return null

    return Math.atan2(dx, -dy) * 180 / Math.PI
  },
}

export const TapeSound = {
  mounted() {
    this.running = false
    this.sync()
  },

  updated() {
    this.sync()
  },

  destroyed() {
    this.stopWhirr(false)
  },

  playbackRate() {
    const stepsPerSecond = Number(this.el.dataset.stepsPerSecond)
    return 0.75 + 0.3 * Math.log10(stepsPerSecond)
  },

  sync() {
    const running = this.el.classList.contains("is-running")

    if (running && !this.running) this.startWhirr()
    if (!running && this.running) this.stopWhirr(true)
    if (running && this.whirr) {
      this.whirr.playbackRate.setTargetAtTime(this.playbackRate(), audio.currentTime, 0.15)
    }

    this.running = running
  },

  startWhirr() {
    playSound("tape-play")

    const buffer = buffers["tape-loop"]
    if (!buffer) return

    const now = audio.currentTime
    this.whirr = audio.createBufferSource()
    this.whirr.buffer = buffer
    this.whirr.loop = true
    this.whirr.loopStart = tapeLoop.start
    this.whirr.loopEnd = tapeLoop.end
    this.whirr.playbackRate.setValueAtTime(this.playbackRate() * 0.6, now)
    this.whirr.playbackRate.setTargetAtTime(this.playbackRate(), now + 0.08, 0.12)

    this.whirrLevel = audio.createGain()
    this.whirrLevel.gain.setValueAtTime(0.0001, now)
    this.whirrLevel.gain.exponentialRampToValueAtTime(tapeLoop.volume, now + 0.25)

    this.whirr.connect(this.whirrLevel).connect(speaker)
    this.whirr.start(now + 0.08, tapeLoop.start)
  },

  stopWhirr(withClunk) {
    if (withClunk) playSound("tape-stop")
    if (!this.whirr) return

    const now = audio.currentTime
    this.whirr.playbackRate.setTargetAtTime(0.35, now, 0.12)
    this.whirrLevel.gain.setTargetAtTime(0.0001, now, 0.1)
    this.whirr.stop(now + 0.6)
    this.whirr = null
  },
}

export const CrtCursor = {
  mounted() {
    this.el.addEventListener("wheel", event => this.scrollByWheel(event), {passive: false})
    this.el.addEventListener("scroll", () => this.drawScrollbar(), {passive: true})
    this.el.addEventListener("scrollend", () => this.scrollByLines(0))

    for (const arrow of this.scrollbar().querySelectorAll("[data-scroll]")) {
      arrow.addEventListener("click", () => this.scrollByLines(Number(arrow.dataset.scroll)))
    }

    this.drawCursor()
  },

  updated() {
    this.drawCursor()
  },

  destroyed() {
    cancelAnimationFrame(this.followFrame)
  },

  scrollbar() {
    return this.el.nextElementSibling
  },

  lineHeight() {
    return parseFloat(getComputedStyle(this.el).lineHeight)
  },

  scrollByWheel(event) {
    event.preventDefault()

    const lines = event.deltaMode === WheelEvent.DOM_DELTA_LINE
      ? event.deltaY
      : event.deltaY / this.lineHeight()
    const wholeLines = Math.max(1, Math.round(Math.abs(lines)))

    this.scrollByLines(Math.sign(lines) * wholeLines)
  },

  scrollByLines(count) {
    const lineHeight = this.lineHeight()
    const lastTopLine = Math.max(0, Math.round((this.el.scrollHeight - this.el.clientHeight) / lineHeight))
    const currentTopLine = Math.round(this.el.scrollTop / lineHeight)
    const targetTopLine = Math.min(lastTopLine, Math.max(0, currentTopLine + count))
    const targetScrollTop = targetTopLine * lineHeight

    if (Math.abs(this.el.scrollTop - targetScrollTop) > 0.5) {
      this.el.scrollTop = targetScrollTop
    }

    this.drawScrollbar()
  },

  drawScrollbar() {
    const lineHeight = this.lineHeight()
    const visibleLines = Math.round(this.el.clientHeight / lineHeight)
    const totalLines = Math.max(visibleLines, Math.round(this.el.scrollHeight / lineHeight))
    const hiddenLines = totalLines - visibleLines
    const topLine = Math.round(this.el.scrollTop / lineHeight)

    const trackLines = visibleLines - 2
    const thumbLines = Math.max(1, Math.min(trackLines, Math.round(trackLines * visibleLines / totalLines)))
    const thumbTop = hiddenLines > 0 ? Math.round((trackLines - thumbLines) * topLine / hiddenLines) : 0

    const scrollbar = this.scrollbar()
    scrollbar.classList.toggle("is-idle", hiddenLines === 0)
    scrollbar.style.setProperty("--thumb-top", thumbTop)
    scrollbar.style.setProperty("--thumb-size", thumbLines)
  },

  drawCursor() {
    const listing = this.el.querySelector("pre")
    if (listing !== this.listing) this.splitListing(listing)

    const cursorIndex = Number(this.el.dataset.cursor)
    const halted = cursorIndex < 0

    if (halted) {
      this.textBeforeCursor.data = this.characters.join("")
      this.cursor.textContent = ""
      this.textAfterCursor.data = ""
      this.drawScrollbar()
      return
    }

    this.textBeforeCursor.data = this.characters.slice(0, cursorIndex).join("")
    this.cursor.textContent = this.characters[cursorIndex]
    this.textAfterCursor.data = this.characters.slice(cursorIndex + 1).join("")

    cancelAnimationFrame(this.followFrame)
    this.followFrame = requestAnimationFrame(() => this.keepCursorInView())
  },

  splitListing(listing) {
    this.listing = listing
    this.characters = Array.from(listing.textContent)

    this.textBeforeCursor = document.createTextNode("")
    this.cursor = document.createElement("span")
    this.cursor.className = "bj-crt-cursor"
    this.textAfterCursor = document.createTextNode("")

    listing.replaceChildren(this.textBeforeCursor, this.cursor, this.textAfterCursor)
  },

  keepCursorInView() {
    const lineHeight = this.lineHeight()
    const cursorLine = Math.round(this.cursor.offsetTop / lineHeight)
    const topLine = Math.round(this.el.scrollTop / lineHeight)
    const visibleLines = Math.round(this.el.clientHeight / lineHeight)
    const cursorVisible = cursorLine >= topLine && cursorLine < topLine + visibleLines - 1

    if (!cursorVisible) {
      const centredTopLine = Math.max(0, cursorLine - Math.floor(visibleLines / 2))
      this.el.scrollTop = centredTopLine * lineHeight
    }

    this.drawScrollbar()
  },
}

const pageFonts = ["VT323", "Michroma", "Jost", "Bungee", "Russo One", "Tinos", "Courier Prime"]

export const BootScreen = {
  mounted() {
    const fontsLoaded = [...document.fonts]
      .filter(font => pageFonts.includes(font.family.replaceAll('"', "")))
      .map(font => font.load())

    const barFilled = this.el.querySelector(".bj-boot-bar i")
      .getAnimations()
      .map(animation => animation.finished)

    Promise.allSettled([...fontsLoaded, ...barFilled]).then(() => {
      this.el.dataset.booted = ""
    })
  },
}

export const PauseWhenHidden = {
  mounted() {
    this.pauseIfHidden = () => {
      if (document.hidden) this.pushEvent("pause", {})
    }

    document.addEventListener("visibilitychange", this.pauseIfHidden)
  },

  destroyed() {
    document.removeEventListener("visibilitychange", this.pauseIfHidden)
  },
}

export const Modal = {
  mounted() {
    this.opener = document.activeElement

    this.el.addEventListener("close", () => this.pushEvent("close_overlay", {}))
    this.el.addEventListener("click", event => {
      const clickedBackdrop = event.target === this.el
      if (clickedBackdrop) this.el.close()
    })

    if (this.el.dataset.openSound) playSound(this.el.dataset.openSound)
    this.el.showModal()
  },

  destroyed() {
    if (this.el.dataset.closeSound) playSound(this.el.dataset.closeSound)
    this.opener?.focus({preventScroll: true})
  },
}

let stopFittingDesk = () => {}

export function initFitDesk() {
  stopFittingDesk()
  if (!document.querySelector(".bj-desk")) return

  let resizeFrame = null

  const fitDesk = () => {
    resizeFrame = null

    const desk = document.querySelector(".bj-desk")
    if (!desk) return

    const scale = Math.min(innerWidth / desk.offsetWidth, innerHeight / desk.offsetHeight, 1.3)
    document.documentElement.style.setProperty("--bj-fit", scale.toFixed(4))
  }

  const fitDeskNextFrame = () => {
    resizeFrame ??= requestAnimationFrame(fitDesk)
  }

  const listeners = new AbortController()
  window.addEventListener("resize", fitDeskNextFrame, {signal: listeners.signal, passive: true})

  fitDesk()
  document.fonts?.ready.then(fitDesk)

  stopFittingDesk = () => {
    listeners.abort()
    cancelAnimationFrame(resizeFrame)
  }
}

export const ManualBook = {
  mounted() {
    this.pages = [...this.el.querySelectorAll(".bj-book-pages > .bj-leaf")]
    this.pages.forEach((page, index) => {
      if (index > 0) page.dataset.n = index
    })

    this.currentPage = 0
    this.turning = false

    this.listeners = new AbortController()
    const signal = this.listeners.signal

    window.addEventListener("resize", () => this.layout(), {signal, passive: true})
    window.addEventListener("keydown", event => {
      if (event.key === "ArrowRight") this.turnPage(1)
      if (event.key === "ArrowLeft") this.turnPage(-1)
    }, {signal})

    for (const corner of this.el.querySelectorAll("[data-turn]")) {
      corner.addEventListener("click", () => this.turnPage(Number(corner.dataset.turn)), {signal})
    }

    this.layout()
  },

  destroyed() {
    this.listeners.abort()
  },

  isSinglePage() {
    return this.el.classList.contains("is-single")
  },

  pagesPerSpread() {
    return this.isSinglePage() ? 1 : 2
  },

  layout() {
    this.el.classList.toggle("is-single", innerWidth < innerHeight * 1.15)
    if (!this.isSinglePage()) this.currentPage -= this.currentPage % 2

    this.el.style.setProperty("--book-scale", 1)
    const scale = Math.min(
      (innerWidth - 24) / this.el.offsetWidth,
      (innerHeight - 24) / this.el.offsetHeight,
      1.3,
    )
    this.el.style.setProperty("--book-scale", scale.toFixed(4))

    this.showSpread(this.currentPage)
  },

  showSpread(leftPage, rightPage = leftPage + 1) {
    const single = this.isSinglePage()

    this.pages.forEach((page, index) => {
      let side = null
      if (index === leftPage) side = single ? "single" : "left"
      if (!single && index === rightPage) side = "right"

      if (side) page.dataset.side = side
      else delete page.dataset.side
    })

    const lastPage = this.pages.length - 1
    this.el.querySelector('[data-turn="-1"]').hidden = leftPage <= 0
    this.el.querySelector('[data-turn="1"]').hidden = leftPage + this.pagesPerSpread() > lastPage
  },

  pageFace(page, side) {
    const copy = page ? page.cloneNode(true) : document.createElement("section")
    copy.classList.add("bj-leaf")
    copy.dataset.side = side
    copy.querySelectorAll("[id]").forEach(node => node.removeAttribute("id"))

    const face = document.createElement("div")
    face.className = "bj-turn-face"
    face.append(copy)
    return face
  },

  turnPage(direction) {
    const forward = direction > 0
    const targetPage = this.currentPage + direction * this.pagesPerSpread()
    const outOfRange = targetPage < 0 || targetPage > this.pages.length - 1
    if (this.turning || outOfRange) return

    playSound(`page-${1 + Math.floor(Math.random() * 3)}`)

    const page = index => this.pages[index]
    let front, back

    if (this.isSinglePage()) {
      front = this.pageFace(page(forward ? this.currentPage : targetPage), "single")
      back = this.pageFace(null, "left")
      this.showSpread(forward ? targetPage : this.currentPage)
    } else if (forward) {
      front = this.pageFace(page(this.currentPage + 1), "right")
      back = this.pageFace(page(targetPage), "left")
      this.showSpread(this.currentPage, targetPage + 1)
    } else {
      front = this.pageFace(page(targetPage + 1), "right")
      back = this.pageFace(page(this.currentPage), "left")
      this.showSpread(targetPage, this.currentPage + 1)
    }

    back.classList.add("bj-turn-back")

    const turningLeaf = document.createElement("div")
    turningLeaf.className = "bj-turn"
    turningLeaf.append(front, back)
    this.el.querySelector(".bj-book-pages").append(turningLeaf)
    this.el.querySelectorAll("[data-turn]").forEach(corner => corner.hidden = true)

    const reducedMotion = matchMedia("(prefers-reduced-motion: reduce)").matches
    const timing = {duration: reducedMotion ? 0 : 700, easing: "cubic-bezier(0.45, 0.05, 0.3, 1)"}

    const flat = {transform: "rotateY(0deg)"}
    const flipped = {transform: "rotateY(-180deg)"}
    const lit = {filter: "brightness(1)"}
    const shaded = {filter: "brightness(0.72)"}

    front.animate(forward ? [lit, shaded] : [shaded, lit], timing)
    back.animate(forward ? [shaded, lit] : [lit, shaded], timing)

    this.turning = true
    let finished = false

    const finishTurn = () => {
      if (finished) return
      finished = true

      turningLeaf.remove()
      this.currentPage = targetPage
      this.showSpread(targetPage)
      this.turning = false
    }

    const flip = turningLeaf.animate(forward ? [flat, flipped] : [flipped, flat], timing)
    flip.finished.then(finishTurn, finishTurn)
    setTimeout(finishTurn, timing.duration + 150)
  },
}
