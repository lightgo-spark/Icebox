import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"

const csrfToken = document
  .querySelector("meta[name='csrf-token']")
  ?.getAttribute("content")

const Hooks = {}

// ─── Auto scroll ──────────────────────────────
Hooks.ScrollToBottom = {
  mounted() { this.scrollToBottom() },
  updated() {
    const el = this.el
    const atBottom = el.scrollHeight - el.scrollTop - el.clientHeight < 150
    if (atBottom) this.scrollToBottom()
  },
  scrollToBottom() { this.el.scrollTop = this.el.scrollHeight }
}

// ─── Thread panel scroll ─────────────────────
Hooks.ThreadScroll = {
  mounted()  { this.el.scrollTop = this.el.scrollHeight },
  updated()  { this.el.scrollTop = this.el.scrollHeight }
}

// ─── Restore username from localStorage ───────
Hooks.RestoreUsername = {
  mounted() {
    const saved = localStorage.getItem("chat_username")
    if (saved && saved.trim() !== "") {
      this.pushEvent("restore_username", { username: saved.trim() })
    }
  }
}

// ─── Typing indicator (debounced) ─────────────
Hooks.TypingHook = {
  mounted() {
    let timer = null
    this.el.addEventListener("input", () => {
      clearTimeout(timer)
      timer = setTimeout(() => { this.pushEvent("typing", {}) }, 400)
    })
  }
}

// ─── @mention autocomplete ────────────────────
Hooks.MentionInput = {
  mounted() {
    this._dropdown = null
    this._users = []
    this._selectedIdx = -1

    this._onInput = () => {
      const val = this.el.value
      const cursor = this.el.selectionStart
      const before = val.slice(0, cursor)
      const match = before.match(/@(\w*)$/)
      if (match) {
        const query = match[1].toLowerCase()
        const all = this.getOnlineUsers()
        const filtered = query === ""
          ? all
          : all.filter(u => u.toLowerCase().startsWith(query))
        filtered.length > 0 ? this.showDropdown(filtered) : this.hideDropdown()
      } else {
        this.hideDropdown()
      }
    }

    this._onKeydown = (e) => {
      if (!this._dropdown) return
      if (e.key === "ArrowDown") {
        e.preventDefault()
        this._selectedIdx = Math.min(this._users.length - 1, this._selectedIdx + 1)
        this.updateActive()
      } else if (e.key === "ArrowUp") {
        e.preventDefault()
        this._selectedIdx = Math.max(0, this._selectedIdx - 1)
        this.updateActive()
      } else if (e.key === "Enter" || e.key === "Tab") {
        if (this._selectedIdx >= 0) { e.preventDefault(); this.selectUser(this._users[this._selectedIdx]) }
      } else if (e.key === "Escape") {
        this.hideDropdown()
      }
    }

    this._onClickOutside = (e) => {
      if (this._dropdown && !this._dropdown.contains(e.target) && e.target !== this.el) {
        this.hideDropdown()
      }
    }

    this.el.addEventListener("input", this._onInput)
    this.el.addEventListener("keydown", this._onKeydown)
    document.addEventListener("mousedown", this._onClickOutside)
  },

  destroyed() {
    this.el.removeEventListener("input", this._onInput)
    this.el.removeEventListener("keydown", this._onKeydown)
    document.removeEventListener("mousedown", this._onClickOutside)
    this.hideDropdown()
  },

  getOnlineUsers() {
    return Array.from(document.querySelectorAll(".user-name"))
      .map(el => el.textContent.trim())
      .filter(u => u && u !== "Me")
  },

  showDropdown(users) {
    this.hideDropdown()
    this._users = users
    this._selectedIdx = 0
    const dropdown = document.createElement("div")
    dropdown.className = "mention-dropdown"
    users.forEach((user, i) => {
      const item = document.createElement("div")
      item.className = "mention-item" + (i === 0 ? " active" : "")
      item.innerHTML = `<span class="mention-avatar" style="background:${this.userColor(user)}">${user[0].toUpperCase()}</span> @${user}`
      item.addEventListener("mousedown", (e) => { e.preventDefault(); this.selectUser(user) })
      item.addEventListener("mouseover", () => { this._selectedIdx = i; this.updateActive() })
      dropdown.appendChild(item)
    })
    const rect = this.el.getBoundingClientRect()
    dropdown.style.cssText = `position:fixed;bottom:${window.innerHeight - rect.top + 6}px;left:${rect.left}px;min-width:200px;z-index:9999`
    document.body.appendChild(dropdown)
    this._dropdown = dropdown
  },

  hideDropdown() {
    if (this._dropdown) { this._dropdown.remove(); this._dropdown = null }
    this._users = []; this._selectedIdx = -1
  },

  updateActive() {
    if (!this._dropdown) return
    this._dropdown.querySelectorAll(".mention-item").forEach((item, i) => {
      item.classList.toggle("active", i === this._selectedIdx)
    })
  },

  selectUser(user) {
    const val = this.el.value
    const cursor = this.el.selectionStart
    const before = val.slice(0, cursor)
    const after = val.slice(cursor)
    const newBefore = before.replace(/@\w*$/, `@${user} `)
    this.el.value = newBefore + after
    this.el.selectionStart = this.el.selectionEnd = newBefore.length
    this.hideDropdown()
    this.el.focus()
  },

  userColor(name) {
    const colors = ["#FF6B6B","#FF8E53","#FFA552","#FFD166","#06D6A0","#118AB2","#7B2D8B","#E63946","#2A9D8F","#E9C46A","#F4A261","#264653","#6A4C93","#1982C4","#8AC926","#FF595E"]
    const sum = name.split("").reduce((a, c) => a + c.charCodeAt(0), 0)
    return colors[sum % colors.length]
  }
}

// ─── LiveSocket init ──────────────────────────
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: Hooks
})

liveSocket.connect()
window.liveSocket = liveSocket

// ─── Enter to send ────────────────────────────
document.addEventListener("keydown", (e) => {
  const input = document.querySelector(".msg-input")
  if (input && document.activeElement === input) {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault()
      input.closest("form")?.requestSubmit()
    }
  }
  const threadInput = document.querySelector(".thread-input")
  if (threadInput && document.activeElement === threadInput) {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault()
      threadInput.closest("form")?.requestSubmit()
    }
  }
  const editInput = document.querySelector(".edit-input")
  if (editInput && document.activeElement === editInput) {
    if (e.key === "Escape") {
      e.preventDefault()
      document.querySelector(".edit-cancel-btn")?.click()
    }
  }
})

// ─── Save username to localStorage ────────────
window.addEventListener("phx:save_username", (e) => {
  if (e.detail?.username) localStorage.setItem("chat_username", e.detail.username)
})

// ─── Mobile sidebar toggle ────────────────────
document.addEventListener("DOMContentLoaded", () => {
  const hamburger = document.getElementById("hamburger-btn")
  const chatApp   = document.getElementById("chat-app")
  const backdrop  = document.getElementById("sidebar-backdrop")

  const openSidebar  = () => chatApp?.classList.add("sidebar-open")
  const closeSidebar = () => chatApp?.classList.remove("sidebar-open")

  hamburger?.addEventListener("click", () => {
    chatApp?.classList.contains("sidebar-open") ? closeSidebar() : openSidebar()
  })
  backdrop?.addEventListener("click", closeSidebar)
  document.querySelectorAll(".room-btn").forEach(btn => {
    btn.addEventListener("click", () => { if (window.innerWidth <= 640) closeSidebar() })
  })
})

// ─── Delete confirm dialog ────────────────────
document.addEventListener("click", (e) => {
  const btn = e.target.closest("[data-confirm]")
  if (!btn) return
  if (!confirm(btn.dataset.confirm)) e.stopImmediatePropagation()
}, true)
