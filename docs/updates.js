document.querySelectorAll("[data-command-block]").forEach((block) => {
  const button = block.querySelector("[data-command-copy]");
  const code = block.querySelector("code");
  const status = block.querySelector(".command-status");
  if (!button || !code || !status) return;

  let copying = false;
  let resetTimer;
  button.hidden = false;

  button.addEventListener("click", async () => {
    if (copying) return;
    copying = true;
    window.clearTimeout(resetTimer);
    button.setAttribute("aria-disabled", "true");
    button.textContent = "복사 중";
    status.textContent = "";

    try {
      if (!navigator.clipboard?.writeText) throw new Error("Clipboard unavailable");
      await navigator.clipboard.writeText(code.textContent);
      button.textContent = "복사됨";
      status.textContent = "명령어를 복사했습니다.";
      resetTimer = window.setTimeout(() => {
        button.textContent = "복사";
        status.textContent = "";
      }, 1800);
    } catch {
      button.textContent = "복사";
      status.textContent = "복사하지 못했습니다. 위 명령어를 직접 선택해 복사하세요.";
    } finally {
      copying = false;
      button.removeAttribute("aria-disabled");
    }
  });
});
