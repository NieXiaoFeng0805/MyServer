// ============================================================
// NXL Server · 首页皮肤脚本 (2026-11-19)
// 1. Hero 标题 + 实时时钟 + 在线数
// 2. 卡包：数量徽标、逐张入场、按服务注入主题色
// 3. 使用说明：右下悬浮球 + 弹窗（取代原顶部大面板）
// 4. 卡片自动登录（沿用原逻辑，改用当前 origin，换 IP 不再失效）
// ============================================================
(function () {
  "use strict";

  // 已存在的旧版说明面板，清掉
  const oldHelp = document.getElementById("usage-help");
  if (oldHelp) oldHelp.remove();

  // ---------- 主题色 ----------
  const ACCENTS = {
    jellyfin: "#9d6bff",
    qbittorrent: "#4a9eff",
    portainer: "#13bef9",
    "code-server": "#38b6ff",
    "nginx proxy manager": "#f2634d",
    "文件管理": "#7bd3ff",
    "知识库": "#ffc46b",
  };
  const HINTS = {
    "Jellyfin": "媒体库 · 电视/手机客户端也走这个地址",
    "qBittorrent": "自动登录 · 下载落在 /data/downloads",
    "Portainer": "容器管理 · 首次需网关密码 nxl",
    "code-server": "自动登录 · 浏览器里直接写代码",
    "Nginx Proxy Manager": "反向代理管理台 · 统一入口 :81",
    "文件管理": "自动登录 · 照片上传到 /data/photos",
    "知识库": "SKILL / SOP 两个目录 · 拖拽上传",
  };
  // 统一入口基址：跟随当前访问的主机名（NPM 在 80 端口）
  const ENTRY = location.protocol + "//" + location.hostname;
  const ON_ENTRY = ["", "80", "443"].indexOf(location.port) !== -1;
  const ENTRY_PATHS = /^\/(jellyfin|qbittorrent|files|portainer|code)(\/|$)/;

  // 把卡片链接改写成"当前主机 + 子路径"，换网段/换 IP 都不用改配置
  function fixLinks() {
    document.querySelectorAll("li.service a[href]").forEach(function (a) {
      var raw = a.getAttribute("href") || "";
      var u;
      try { u = new URL(raw, location.href); } catch (e) { return; }
      // 只改写"服务子路径"和 NPM 管理台(:81)，其余外链一律不动
      var isService = ENTRY_PATHS.test(u.pathname) || u.port === "81";
      if (!isService) return;
      if (u.hostname !== location.hostname) u.hostname = location.hostname;
      var next = u.toString();
      if (a.getAttribute("href") !== next) a.setAttribute("href", next);
    });
  }

  const accentOf = (name) => ACCENTS[(name || "").trim().toLowerCase()] || "#6ea8ff";

  // ---------- Hero ----------
  function injectHero() {
    if (document.querySelector(".nxl-hero")) return;
    const info = document.getElementById("information-widgets");
    const anchor = info && info.parentElement;
    if (!anchor) return;
    const hero = document.createElement("div");
    hero.className = "nxl-hero";
    hero.innerHTML = `
      <div>
        <div class="nxl-hero-title">
          <h1>MyServer</h1>
          <div class="nxl-pulse"></div>
        </div>
        <p class="nxl-hero-sub" id="nxl-hero-sub">家庭服务器 · 正在同步</p>
        <p class="nxl-hero-tip">悬停卡片看详情 · 点击直达服务 · 右下角 ? 查看说明</p>
      </div>
      <div class="nxl-clock">
        <b id="nxl-clock-time">--:--</b>
        <span id="nxl-clock-date"></span>
      </div>`;
    anchor.insertBefore(hero, anchor.firstChild);
    tickClock();
  }

  function tickClock() {
    const t = document.getElementById("nxl-clock-time");
    const d = document.getElementById("nxl-clock-date");
    const sub = document.getElementById("nxl-hero-sub");
    if (!t) return;
    const now = new Date();
    t.textContent = now.toLocaleTimeString("zh-CN", { hour: "2-digit", minute: "2-digit" });
    if (d) {
      d.textContent = now.toLocaleDateString("zh-CN", {
        month: "long", day: "numeric", weekday: "short",
      });
    }
    if (sub) {
      const n = document.querySelectorAll(".services-group").length;
      const cards = document.querySelectorAll("li.service").length;
      sub.textContent = n
        ? `家庭服务器 · ${n} 个卡包 · ${cards} 项服务在线`
        : "家庭服务器";
    }
  }
  setInterval(tickClock, 20000);

  // ---------- 卡包增强 ----------
  function enhancePacks() {
    document.querySelectorAll(".services-group").forEach((group) => {
      // 数量徽标
      const btn = group.querySelector(":scope > button");
      const list = group.querySelector(".services-list");
      if (btn && list && !btn.querySelector(".pck-count")) {
        const n = list.querySelectorAll(":scope > li.service").length;
        const badge = document.createElement("span");
        badge.className = "pck-count";
        badge.textContent = n + " 项";
        btn.appendChild(badge);
      }
      // 逐张入场 + 主题色
      if (list) {
        list.querySelectorAll(":scope > li.service").forEach((li, i) => {
          li.style.setProperty("--i", i);
          const name = li.dataset.name || li.querySelector(".service-name")?.childNodes[0]?.textContent || "";
          li.style.setProperty("--accent", accentOf(name));
          if (li.dataset.nxlAccent !== "1") {
            li.dataset.nxlAccent = "1";
          }
          // 悬停展开的说明条（没有 widget 附加行的卡片也能"展开"）
          if (!li.querySelector('.nxl-hint')) {
            const card = li.querySelector('.service-card');
            if (card) {
              const hint = document.createElement('div');
              hint.className = 'nxl-hint';
              hint.innerHTML = '<span class="nxl-hint-arrow">→</span>' + (HINTS[name.trim()] || '点击进入服务');
              card.appendChild(hint);
            }
          }
          // 标记空状态行（"-" / 空白），悬停时只展开有内容的行
          li.querySelectorAll(".service-card > .flex.flex-col.pb-1.mx-1 > div").forEach((row) => {
            const txt = (row.textContent || "").trim();
            row.classList.toggle("nxl-empty", txt === "-" || txt === "");
          });
        });
      }
    });
  }

  // ---------- 使用说明弹窗 ----------
  const GUIDE = [
    ["🎬", "Jellyfin", "看电影 / 剧集 / 动漫，点封面直接播放（账号 root）"],
    ["⬇️", "qBittorrent", "粘贴磁力或种子链接开始下载，文件存 data 盘"],
    ["🐳", "Portainer", "查看 / 重启容器、读日志（首次需网关密码）"],
    ["💻", "code-server", "网页版 VS Code，点卡片自动登录直接写代码"],
    ["🔀", "NPM 管理台", "统一入口与反向代理设置，平时不用碰（:81）"],
    ["📁", "文件管理", "上传 / 浏览照片与文件，点卡片自动登录"],
    ["📚", "知识库", "SKILL 与 SOP 两个目录，拖拽上传脚本 / 文档"],
  ];

  function ensureModal() {
    if (document.getElementById("nxl-modal")) return;
    const modal = document.createElement("div");
    modal.id = "nxl-modal";
    modal.innerHTML = `
      <div id="nxl-modal-card" role="dialog" aria-modal="true" aria-label="使用说明">
        <h3>使用说明</h3>
        <p class="nxl-modal-sub">卡片按卡包分组，悬停可展开详情；点击卡片直达对应服务。</p>
        <div class="nxl-guide-grid">
          ${GUIDE.map(
            ([icon, name, desc]) =>
              `<div class="nxl-guide-item"><i>${icon}</i><div><b>${name}</b><span>${desc}</span></div></div>`
          ).join("")}
        </div>
        <div class="nxl-pw">🔑 网关密码 <code>nxl</code> / <code>YBYeLOGYybU80PaA1</code> — 访问 Portainer、code-server 时输入一次，浏览器会记住。</div>
      </div>`;
    document.body.appendChild(modal);
    modal.addEventListener("click", (e) => {
      if (e.target === modal) closeModal();
    });
  }

  function ensureFab() {
    if (document.getElementById("nxl-fab")) return;
    const fab = document.createElement("button");
    fab.id = "nxl-fab";
    fab.type = "button";
    fab.title = "使用说明";
    fab.textContent = "?";
    fab.addEventListener("click", openModal);
    document.body.appendChild(fab);
  }
  const openModal = () => {
    ensureModal();
    document.getElementById("nxl-modal").classList.add("open");
  };
  const closeModal = () => document.getElementById("nxl-modal")?.classList.remove("open");
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") closeModal();
  });

  // ---------- 自动登录 ----------
  const CODE_PW = "000805";
  const QB_USER = "admin";
  const QB_PW = "t2ShnAZG2";
  const FILES_PW = "YBYeLOGYybU80PaA1";

  function openTab(href) {
    try { return window.open(href, "_blank"); } catch (e) { return null; }
  }
  function reloadTab(w, href, delay) {
    setTimeout(() => {
      try { if (w && !w.closed) w.location.href = href; } catch (e) {}
    }, delay || 900);
  }

  function autoLoginCode() {
    const base = ENTRY + "/code/";
    const w = openTab(base);
    let tries = 0;
    (function attempt() {
      fetch(ENTRY + "/code/login", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: "password=" + encodeURIComponent(CODE_PW),
        credentials: "include",
      })
        .then((resp) => {
          if (resp.ok) reloadTab(w, base);
          else if (++tries < 8) setTimeout(attempt, 2500);
        })
        .catch(() => { if (++tries < 8) setTimeout(attempt, 2500); });
    })();
  }

  function autoLoginQb() {
    const base = ENTRY + "/qbittorrent/";
    const w = openTab(base);
    fetch(ENTRY + "/qbittorrent/api/v2/auth/login", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: "username=" + encodeURIComponent(QB_USER) + "&password=" + encodeURIComponent(QB_PW),
      credentials: "include",
    })
      .catch(() => {})
      .finally(() => reloadTab(w, base));
  }

  function autoLoginFiles(targetHref) {
    const w = openTab(targetHref);
    fetch(ENTRY + "/files/api/auth/login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ username: "guest", password: FILES_PW }),
      credentials: "include",
    })
      .then((r) => r.json())
      .then((d) => {
        if (d && d.code === 200 && d.data && d.data.token) {
          try { localStorage.setItem("token", d.data.token); } catch (e) {}
        }
      })
      .catch(() => {})
      .finally(() => reloadTab(w, targetHref));
  }

  document.addEventListener("click", function (e) {
    if (e.button !== 0 || e.ctrlKey || e.metaKey || e.shiftKey) return;
    if (!ON_ENTRY) return;
    const a = e.target.closest("a[href]");
    if (!a) return;
    const href = a.getAttribute("href") || "";
    if (href.includes("/files")) {
      e.preventDefault();
      autoLoginFiles(a.href);
    } else if (href.includes("/code")) {
      e.preventDefault();
      autoLoginCode();
    } else if (href.includes("qbittorrent")) {
      e.preventDefault();
      autoLoginQb();
    }
  });

  // ---------- 启动 + 兜底重注入（React 每次重渲染会冲掉节点） ----------
  function apply() {
    if (document.title !== "MyServer") document.title = "MyServer";
    injectHero();
    enhancePacks();
    ensureFab();
    fixLinks();
    tickClock();
  }
  apply();
  setInterval(apply, 1500);

  // 侧边栏 / 分组折叠时补一次
  document.addEventListener("click", (e) => {
    if (e.target.closest(".services-group > button")) setTimeout(apply, 60);
  });
})();
