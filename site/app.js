"use strict";

for (const build of window.TUNNELBAR_DOWNLOADS || []) {
  // Restrict the generated configuration to this bundle's own download directory.
  if (!["arm64", "x86_64", "universal"].includes(build.arch) || !/^downloads\/[A-Za-z0-9._-]+\.zip$/.test(build.href)) continue;
  const platforms = build.arch === "universal" ? ["arm64", "x86_64"] : [build.arch];
  for (const platform of platforms) {
    const link = document.querySelector(`[data-platform="${platform}"]`);
    const metadata = document.querySelector(`[data-meta="${platform}"]`);
    if (!link || !metadata) continue;
    link.href = build.href;
    link.setAttribute("download", "");
    link.textContent = build.arch === "universal" ? "Download universal build ↓" : "Download development build ↓";
    metadata.textContent = `v${build.version} · ${build.size} · ${build.arch === "universal" ? "Universal 2 · " : ""}ZIP`;
    if (build.sha256 && /^[a-f0-9]{64}$/.test(build.sha256)) {
      const checksum = document.createElement("a");
      checksum.href = `${build.href}.sha256`;
      checksum.className = "checksum-link";
      checksum.textContent = "SHA-256 checksum ↗";
      link.parentElement.append(checksum);
    }
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
