document.querySelectorAll("[data-command-switcher]").forEach((switcher) => {
  const tabs = Array.from(switcher.querySelectorAll('[role="tab"]'));
  const panels = tabs.map((tab) => document.getElementById(tab.getAttribute("aria-controls")));
  const button = switcher.querySelector("[data-command-copy]");
  const status = switcher.querySelector(".command-status");
  const toolbar = switcher.querySelector(".command-toolbar");
  if (!tabs.length || panels.some((panel) => !panel?.querySelector("code")) || !button || !status || !toolbar) return;

  let activeIndex = 0;
  let revision = 0;
  let copying = false;
  let resetTimer;

  const selectTab = (index) => {
    activeIndex = index;
    revision += 1;
    window.clearTimeout(resetTimer);
    status.textContent = "";
    button.textContent = copying ? "복사 중" : "복사";
    button.setAttribute("aria-label", panels[index].dataset.copyLabel);
    tabs.forEach((tab, position) => {
      const selected = position === index;
      tab.setAttribute("aria-selected", String(selected));
      tab.tabIndex = selected ? 0 : -1;
      panels[position].hidden = !selected;
      panels[position].setAttribute("role", "tabpanel");
      panels[position].setAttribute("aria-labelledby", tab.id);
    });
  };

  tabs.forEach((tab, index) => {
    tab.addEventListener("click", () => selectTab(index));
    tab.addEventListener("keydown", (event) => {
      let nextIndex;
      if (event.key === "ArrowRight") nextIndex = (index + 1) % tabs.length;
      else if (event.key === "ArrowLeft") nextIndex = (index + tabs.length - 1) % tabs.length;
      else if (event.key === "Home") nextIndex = 0;
      else if (event.key === "End") nextIndex = tabs.length - 1;
      else return;
      event.preventDefault();
      selectTab(nextIndex);
      tabs[nextIndex].focus();
    });
  });

  button.addEventListener("click", async () => {
    if (copying) return;
    copying = true;
    const copyRevision = revision;
    const text = panels[activeIndex].querySelector("code").textContent;
    window.clearTimeout(resetTimer);
    button.setAttribute("aria-disabled", "true");
    button.textContent = "복사 중";
    status.textContent = "";

    try {
      if (!navigator.clipboard?.writeText) throw new Error("Clipboard unavailable");
      await navigator.clipboard.writeText(text);
      if (copyRevision !== revision) return;
      button.textContent = "복사됨";
      status.textContent = "명령어를 복사했습니다.";
      resetTimer = window.setTimeout(() => {
        button.textContent = "복사";
        status.textContent = "";
      }, 1800);
    } catch {
      if (copyRevision !== revision) return;
      button.textContent = "복사";
      status.textContent = "복사하지 못했습니다. 위 명령어를 직접 선택해 복사하세요.";
    } finally {
      copying = false;
      button.removeAttribute("aria-disabled");
      if (copyRevision !== revision) button.textContent = "복사";
    }
  });

  selectTab(0);
  switcher.classList.add("is-enhanced");
  toolbar.hidden = false;
});
