// Draws the cursor on the CRT listing. The server sends the listing once per cartridge and
// then only a character index in data-cursor, so a frame moves one highlight instead of
// resending the whole program.
export const CrtCursor = {
  mounted() {
    // Scroll by whole lines, like a terminal, so the listing never sits between rows.
    this.el.addEventListener("wheel", e => {
      e.preventDefault()
      const lines = e.deltaMode === 1 ? e.deltaY : e.deltaY / this.line()
      this.scrollLines(Math.sign(lines) * Math.max(1, Math.round(Math.abs(lines))))
    }, {passive: false})
    this.el.addEventListener("scroll", () => this.drawBar(), {passive: true})
    this.el.addEventListener("scrollend", () => this.scrollLines(0))
    this.el.nextElementSibling.querySelectorAll("[data-scroll]").forEach(arrow =>
      arrow.addEventListener("click", () => this.scrollLines(Number(arrow.dataset.scroll))))
    this.paint()
  },
  updated() { this.paint() },
  line() { return parseFloat(getComputedStyle(this.el).lineHeight) },
  scrollLines(n) {
    const line = this.line()
    const last = Math.max(0, Math.round((this.el.scrollHeight - this.el.clientHeight) / line))
    const row = Math.min(last, Math.max(0, Math.round(this.el.scrollTop / line) + n))
    if (Math.abs(this.el.scrollTop - row * line) > 0.5) this.el.scrollTop = row * line
    this.drawBar()
  },
  // The scrollbar's thumb is a whole number of rows tall and moves a row at a time.
  drawBar() {
    const line = this.line()
    const rows = Math.round(this.el.clientHeight / line)
    const total = Math.max(rows, Math.round(this.el.scrollHeight / line))
    const track = rows - 2
    const size = Math.max(1, Math.min(track, Math.round(track * rows / total)))
    const last = total - rows
    const first = Math.round(this.el.scrollTop / line)
    const top = last > 0 ? Math.round((track - size) * first / last) : 0
    const bar = this.el.nextElementSibling
    bar.classList.toggle("is-idle", total <= rows)
    bar.style.setProperty("--thumb-top", top)
    bar.style.setProperty("--thumb-size", size)
  },
  paint() {
    const pre = this.el.querySelector("pre")
    if (pre !== this.pre) {
      this.pre = pre
      this.chars = Array.from(pre.textContent)
      this.before = document.createTextNode("")
      this.cursor = document.createElement("span")
      this.cursor.className = "bj-crt-cursor"
      this.after = document.createTextNode("")
      pre.replaceChildren(this.before, this.cursor, this.after)
    }
    const at = Number(this.el.dataset.cursor)
    if (at < 0) {
      this.before.data = this.chars.join("")
      this.cursor.textContent = ""
      this.after.data = ""
      this.drawBar()
      return
    }
    this.before.data = this.chars.slice(0, at).join("")
    this.cursor.textContent = this.chars[at]
    this.after.data = this.chars.slice(at + 1).join("")
    this.follow()
  },
  // Scroll whole lines only, so the listing stays on the screen's character grid.
  follow() {
    const line = parseFloat(getComputedStyle(this.el).lineHeight)
    const row = Math.round(this.cursor.offsetTop / line)
    const first = Math.round(this.el.scrollTop / line)
    const rows = Math.round(this.el.clientHeight / line)
    if (row < first || row >= first + rows - 1) {
      this.el.scrollTop = Math.max(0, row - Math.floor(rows / 2)) * line
    }
    this.drawBar()
  },
}

let cleanup = () => {}

// Scales the whole desk to fit the window, so the page reads as one scene with no scrolling.
export function initFitDesk() {
  cleanup()
  if (!document.querySelector(".bj-desk")) return
  const listeners = new AbortController()
  const fit = () => {
    const desk = document.querySelector(".bj-desk")
    if (!desk) return
    const scale = Math.min(innerWidth / desk.offsetWidth, innerHeight / desk.offsetHeight, 1.3)
    document.documentElement.style.setProperty("--bj-fit", scale.toFixed(4))
  }
  fit()
  document.fonts?.ready.then(fit)
  window.addEventListener("resize", fit, {signal: listeners.signal, passive: true})
  cleanup = () => listeners.abort()
}

// Shows the manual as a booklet: a two-page spread on wide screens, one page on narrow
// ones, with pages that turn about the spine.
export const ManualBook = {
  mounted() {
    this.pages = [...this.el.querySelectorAll(".bj-book-pages > .bj-leaf")]
    this.pages.forEach((page, i) => { if (i > 0) page.dataset.n = i })
    this.at = 0
    this.busy = false
    this.listeners = new AbortController()
    const signal = this.listeners.signal
    window.addEventListener("resize", () => this.layout(), {signal, passive: true})
    window.addEventListener("keydown", e => {
      if (e.key === "ArrowRight") this.turn(1)
      if (e.key === "ArrowLeft") this.turn(-1)
    }, {signal})
    this.el.querySelectorAll("[data-turn]").forEach(corner =>
      corner.addEventListener("click", () => this.turn(Number(corner.dataset.turn)), {signal}))
    this.layout()
  },
  destroyed() { this.listeners.abort() },

  single() { return this.el.classList.contains("is-single") },
  step() { return this.single() ? 1 : 2 },

  layout() {
    this.el.classList.toggle("is-single", innerWidth < innerHeight * 1.15)
    if (!this.single()) this.at -= this.at % 2
    this.el.style.setProperty("--book-scale", 1)
    const scale = Math.min((innerWidth - 24) / this.el.offsetWidth, (innerHeight - 24) / this.el.offsetHeight, 1.3)
    this.el.style.setProperty("--book-scale", scale.toFixed(4))
    this.show(this.at)
  },

  // Puts page `at` (and its facing page) on the spread.
  show(at, rightOverride) {
    const single = this.single()
    this.pages.forEach((page, i) => {
      let side = null
      if (single && i === at) side = "single"
      if (!single && i === at) side = "left"
      if (!single && i === (rightOverride ?? at + 1)) side = "right"
      if (side) page.dataset.side = side
      else delete page.dataset.side
    })
    // A corner only curls up where there is a page to turn to.
    this.el.querySelector('[data-turn="-1"]').hidden = at <= 0
    this.el.querySelector('[data-turn="1"]').hidden = at + this.step() > this.pages.length - 1
  },

  face(page, side) {
    const face = document.createElement("div")
    face.className = "bj-turn-face"
    const copy = page ? page.cloneNode(true) : document.createElement("section")
    copy.classList.add("bj-leaf")
    copy.dataset.side = side
    copy.querySelectorAll("[id]").forEach(node => node.removeAttribute("id"))
    face.append(copy)
    return face
  },

  turn(dir) {
    const step = this.step()
    const next = this.at + dir * step
    if (this.busy || next < 0 || next > this.pages.length - 1) return
    const single = this.single()
    const p = i => this.pages[i]
    const leaf = document.createElement("div")
    leaf.className = "bj-turn"
    let front, back
    if (single) {
      // Forward: the current page lifts away. Back: the previous page lays down over it.
      front = this.face(dir > 0 ? p(this.at) : p(next), "single")
      back = this.face(null, "left")
      this.show(dir > 0 ? next : this.at)
    } else if (dir > 0) {
      front = this.face(p(this.at + 1), "right")
      back = this.face(p(next), "left")
      this.show(this.at, next + 1)
    } else {
      front = this.face(p(next + 1), "right")
      back = this.face(p(this.at), "left")
      this.show(next, this.at + 1)
    }
    back.classList.add("bj-turn-back")
    leaf.append(front, back)
    this.el.querySelector(".bj-book-pages").append(leaf)
    this.el.querySelectorAll("[data-turn]").forEach(corner => corner.hidden = true)

    const flat = "rotateY(0deg)", over = "rotateY(-180deg)"
    const frames = dir > 0 ? [flat, over] : [over, flat]
    const reduced = matchMedia("(prefers-reduced-motion: reduce)").matches
    const timing = {duration: reduced ? 0 : 700, easing: "cubic-bezier(0.45, 0.05, 0.3, 1)"}
    const shade = dir > 0 ? ["brightness(1)", "brightness(0.72)"] : ["brightness(0.72)", "brightness(1)"]
    front.animate(shade.map(filter => ({filter})), timing)
    back.animate([...shade].reverse().map(filter => ({filter})), timing)
    this.busy = true
    const target = next
    let done = false
    const finish = () => {
      if (done) return
      done = true
      leaf.remove()
      this.at = target
      this.show(this.at)
      this.busy = false
    }
    leaf.animate(frames.map(transform => ({transform})), timing).finished.then(finish, finish)
    // Some browsers report the finish late or not at all when the tab is throttled.
    setTimeout(finish, timing.duration + 150)
  },
}
