/* ============================================================
   NakanoWenku 官网交互
   主题切换 / 滚动入场 / 历史版本折叠 / 附注懒加载 / 模态 / 复制
   ============================================================ */
(function () {
  "use strict";

  const doc = document.documentElement;
  const STORE_KEY = "nw.site.theme";

  /* ---------- 主题 ---------- */
  function applyTheme(theme) {
    doc.setAttribute("data-theme", theme);
    const meta = document.querySelector('meta[name="theme-color"]');
    if (meta) meta.setAttribute("content", theme === "light" ? "#f6f6f3" : "#000000");
    try { localStorage.setItem(STORE_KEY, theme); } catch (e) { /* 忽略隐私模式 */ }
  }

  (function initTheme() {
    let saved = null;
    try { saved = localStorage.getItem(STORE_KEY); } catch (e) { /* noop */ }
    if (saved === "light" || saved === "dark") {
      applyTheme(saved);
      return;
    }
    const prefersLight = window.matchMedia("(prefers-color-scheme: light)").matches;
    applyTheme(prefersLight ? "light" : "dark");
  })();

  const themeToggle = document.getElementById("themeToggle");
  if (themeToggle) {
    themeToggle.addEventListener("click", function () {
      applyTheme(doc.getAttribute("data-theme") === "light" ? "dark" : "light");
    });
  }

  /* ---------- 导航吸顶 ---------- */
  const nav = document.getElementById("nav");
  let lastStuck = false;
  function onScroll() {
    const stuck = window.scrollY > 24;
    if (stuck !== lastStuck && nav) {
      nav.classList.toggle("is-stuck", stuck);
      lastStuck = stuck;
    }
  }
  window.addEventListener("scroll", onScroll, { passive: true });
  onScroll();

  /* ---------- 滚动入场 ---------- */
  const reveals = Array.prototype.slice.call(document.querySelectorAll(".reveal"));
  if ("IntersectionObserver" in window) {
    const io = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          const el = entry.target;
          const delay = Number(el.dataset.delay || 0);
          window.setTimeout(function () { el.classList.add("is-in"); }, delay);
          io.unobserve(el);
        });
      },
      { rootMargin: "0px 0px -12% 0px", threshold: 0.12 }
    );
    reveals.forEach(function (el, i) {
      if (el.closest(".feature-grid")) el.dataset.delay = String((i % 3) * 70);
      io.observe(el);
    });
  } else {
    reveals.forEach(function (el) { el.classList.add("is-in"); });
  }

  /* ---------- 历史版本 ---------- */
  const historyToggle = document.getElementById("historyToggle");
  const history = document.getElementById("history");
  if (historyToggle && history) {
    historyToggle.addEventListener("click", function () {
      const open = historyToggle.getAttribute("aria-expanded") === "true";
      historyToggle.setAttribute("aria-expanded", String(!open));
      if (open) {
        history.hidden = true;
      } else {
        history.hidden = false;
        // 重新触发逐行入场动画
        Array.prototype.forEach.call(history.children, function (li) {
          li.style.animation = "none";
          void li.offsetWidth;
          li.style.animation = "";
        });
      }
    });
  }

  /* ---------- 模态 ---------- */
  let activeModal = null;
  let lastFocus = null;

  function openModal(id) {
    const el = document.getElementById(id);
    if (!el) return;
    lastFocus = document.activeElement;
    activeModal = el;
    el.hidden = false;
    document.body.style.overflow = "hidden";
    const focusable = el.querySelector("[data-close], .btn");
    if (focusable) focusable.focus({ preventScroll: true });
  }

  function closeModal() {
    if (!activeModal) return;
    activeModal.hidden = true;
    activeModal = null;
    document.body.style.overflow = "";
    if (lastFocus && lastFocus.focus) lastFocus.focus({ preventScroll: true });
  }

  document.addEventListener("click", function (event) {
    const closer = event.target.closest("[data-close]");
    if (closer) {
      event.preventDefault();
      closeModal();
    }
  });

  document.addEventListener("keydown", function (event) {
    if (event.key === "Escape") closeModal();
  });

  const iosBtn = document.getElementById("iosBtn");
  if (iosBtn) iosBtn.addEventListener("click", function () { openModal("iosModal"); });

  const donateBtn = document.getElementById("donateBtn");
  if (donateBtn) donateBtn.addEventListener("click", function () { openModal("donateModal"); });

  /* ---------- Toast ---------- */
  const toast = document.getElementById("toast");
  let toastTimer = null;
  function showToast(text) {
    if (!toast) return;
    toast.textContent = text;
    toast.classList.add("is-on");
    if (toastTimer) window.clearTimeout(toastTimer);
    toastTimer = window.setTimeout(function () {
      toast.classList.remove("is-on");
    }, 1900);
  }

  /* ---------- 复制群号 ---------- */
  const copyQQ = document.getElementById("copyQQ");
  if (copyQQ) {
    copyQQ.addEventListener("click", function () {
      const raw = (document.getElementById("qqNumber") || {}).textContent || "1126557550";
      const text = raw.trim();
      const done = function () { showToast("群号已复制：" + text); };
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(done, function () { fallbackCopy(text, done); });
      } else {
        fallbackCopy(text, done);
      }
    });
  }

  function fallbackCopy(text, done) {
    const ta = document.createElement("textarea");
    ta.value = text;
    ta.setAttribute("readonly", "");
    ta.style.cssText = "position:fixed;top:-1000px;left:-1000px;opacity:0";
    document.body.appendChild(ta);
    ta.select();
    try { document.execCommand("copy"); done(); } catch (e) { showToast("复制失败，请手动选择"); }
    document.body.removeChild(ta);
  }

  /* ---------- 附注：展开 + 懒加载文本 ---------- */
  const notesToggle = document.getElementById("notesToggle");
  const notes = document.getElementById("notes");
  if (notesToggle && notes) {
    notesToggle.addEventListener("click", function () {
      const open = notesToggle.getAttribute("aria-expanded") === "true";
      notesToggle.setAttribute("aria-expanded", String(!open));
      notes.hidden = open;
    });
  }

  const textCache = {};

  function loadNote(item) {
    const src = item.getAttribute("data-src");
    const body = item.querySelector(".note-body");
    if (!src || !body) return;
    if (textCache[src]) {
      renderNote(body, textCache[src]);
      return;
    }
    fetch(src, { cache: "force-cache" })
      .then(function (res) {
        if (!res.ok) throw new Error("HTTP " + res.status);
        return res.text();
      })
      .then(function (text) {
        textCache[src] = text;
        renderNote(body, text);
      })
      .catch(function () {
        body.innerHTML = "";
        const p = document.createElement("p");
        p.textContent = "文档读取失败，请稍后重试，或在仓库 docs/assets/texts/ 下查看原文。";
        body.appendChild(p);
      });
  }

  function renderNote(body, text) {
    body.innerHTML = "";
    const summary = body.parentElement ? body.parentElement.querySelector("summary") : null;
    const heading = summary ? summary.textContent.trim() : "";
    const blocks = text.replace(/\r\n/g, "\n").split(/\n{2,}/);
    blocks.forEach(function (block, index) {
      const trimmed = block.trim();
      if (!trimmed) return;
      // 文档首行往往是自己的标题，与折叠项标题重复，跳过
      if (index === 0 && heading && trimmed.replace(/\s+/g, "") === heading.replace(/\s+/g, "")) return;
      const p = document.createElement("p");
      p.textContent = trimmed;
      body.appendChild(p);
    });
  }

  Array.prototype.forEach.call(document.querySelectorAll(".note-item"), function (item) {
    item.addEventListener("toggle", function () {
      if (item.open) loadNote(item);
    });
    // 初始就处于展开状态的条目不会触发 toggle，需要主动加载一次
    if (item.open) loadNote(item);
  });

  /* ---------- 同步最新版本号（失败则保留页面上写死的版本） ---------- */
  (function syncLatest() {
    const verEl = document.getElementById("androidVersion");
    const btnEl = document.getElementById("androidDownload");
    const labelEl = document.getElementById("androidDownloadLabel");
    if (!verEl || !btnEl) return;
    // 同源清单：不再依赖 raw.githubusercontent.com（国内经常被墙）
    const manifest = "version.json";
    fetch(manifest, { cache: "no-store" })
      .then(function (res) { return res.ok ? res.json() : null; })
      .then(function (data) {
        if (!data || !data.versionName) return;
        const name = String(data.versionName).trim();
        if (!/^\d+(\.\d+)+$/.test(name)) return;
        verEl.textContent = "v" + name;
        if (labelEl) labelEl.textContent = "安装安卓版 v" + name;
        if (data.changelog && String(data.changelog).trim()) {
          btnEl.setAttribute("title", "本次更新：" + String(data.changelog).trim().split("\n")[0]);
        }
      })
      .catch(function () { /* 离线或跨域失败时保持页面默认值 */ });
  })();

  /* ---------- 平滑锚点（兼容不支持 scroll-behavior 的浏览器） ---------- */
  document.addEventListener("click", function (event) {
    const link = event.target.closest('a[href^="#"]');
    if (!link) return;
    const id = link.getAttribute("href");
    if (!id || id === "#") return;
    const target = document.querySelector(id);
    if (!target) return;
    event.preventDefault();
    const top = target.getBoundingClientRect().top + window.scrollY - 76;
    window.scrollTo({ top: top, behavior: "smooth" });
    history.replaceState(null, "", id);
  });
})();
