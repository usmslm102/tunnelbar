"use strict";

const tabs = Array.from(document.querySelectorAll('[role="tab"]'));
function selectTab(tab) {
  for (const item of tabs) {
    const selected = item === tab;
    item.setAttribute("aria-selected", String(selected));
    item.tabIndex = selected ? 0 : -1;
    document.getElementById(item.getAttribute("aria-controls")).hidden = !selected;
  }
}
for (const [index, tab] of tabs.entries()) {
  tab.addEventListener("click", () => selectTab(tab));
  tab.addEventListener("keydown", (event) => {
    let target;
    if (event.key === "ArrowRight") target = tabs[(index + 1) % tabs.length];
    if (event.key === "ArrowLeft") target = tabs[(index - 1 + tabs.length) % tabs.length];
    if (event.key === "Home") target = tabs[0];
    if (event.key === "End") target = tabs[tabs.length - 1];
    if (target) { event.preventDefault(); selectTab(target); target.focus(); }
  });
}

for (const build of window.TUNNELBAR_DOWNLOADS || []) {
  // Restrict the generated configuration to this bundle's own download directory.
  if (!["arm64", "x86_64"].includes(build.arch) || !/^downloads\/[A-Za-z0-9._-]+\.zip$/.test(build.href)) continue;
  const link = document.querySelector(`[data-platform="${build.arch}"]`);
  const metadata = document.querySelector(`[data-meta="${build.arch}"]`);
  if (!link || !metadata) continue;
  link.href = build.href;
  link.setAttribute("download", "");
  link.textContent = "Download development build ↓";
  metadata.textContent = `v${build.version} · ${build.size} · ZIP`;
  if (build.sha256 && /^[a-f0-9]{64}$/.test(build.sha256)) {
    const checksum = document.createElement("a");
    checksum.href = `${build.href}.sha256`;
    checksum.className = "checksum-link";
    checksum.textContent = "SHA-256 checksum ↗";
    link.parentElement.append(checksum);
  }
}

document.getElementById("copy-command").addEventListener("click", async () => {
  const code = document.getElementById("install-command");
  const status = document.getElementById("copy-status");
  try {
    await navigator.clipboard.writeText(code.textContent);
    status.textContent = "Command copied. Paste it into Terminal.";
  } catch {
    const selection = window.getSelection();
    const range = document.createRange();
    range.selectNodeContents(code);
    selection.removeAllRanges();
    selection.addRange(range);
    status.textContent = "Command selected. Use your browser’s Copy command.";
  }
});

if ("IntersectionObserver" in window && !window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
  const observer = new IntersectionObserver((entries) => {
    for (const entry of entries) if (entry.isIntersecting) {
      entry.target.classList.add("visible"); observer.unobserve(entry.target);
    }
  }, { threshold: 0.12 });
  for (const element of document.querySelectorAll(".reveal")) {
    element.classList.add("will-reveal"); observer.observe(element);
  }
}
