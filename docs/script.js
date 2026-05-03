const faqItems = document.querySelectorAll(".faq-list details");
const featureSection = document.querySelector(".features-section");
const featureSteps = Array.from(document.querySelectorAll("[data-feature-step]"));
const featureSegments = [
  { start: 0, end: 0.78 },
  { start: 0.78, end: 0.86 },
  { start: 0.86, end: 0.94 },
  { start: 0.94, end: 1 },
];
const finderSnapThresholds = {
  installEnter: 0.08,
  beforeReturn: 0.025,
  afterEnter: 0.5,
  installReturn: 0.42,
};
const finderSnapSettleMs = 120;

const clamp = (value, min = 0, max = 1) => Math.min(max, Math.max(min, value));

faqItems.forEach((item) => {
  item.addEventListener("toggle", () => {
    if (!item.open) return;

    faqItems.forEach((otherItem) => {
      if (otherItem !== item) {
        otherItem.removeAttribute("open");
      }
    });
  });
});

let currentFinderStage = "before";
let pendingFinderStage = "before";
let finderSnapTimer = 0;

const getFinderStage = (progress, currentStage = currentFinderStage) => {
  if (currentStage === "after") {
    if (progress <= finderSnapThresholds.beforeReturn) return "before";
    if (progress <= finderSnapThresholds.installReturn) return "install";
    return "after";
  }

  if (currentStage === "install") {
    if (progress <= finderSnapThresholds.beforeReturn) return "before";
    if (progress >= finderSnapThresholds.afterEnter) return "after";
    return "install";
  }

  if (progress >= finderSnapThresholds.afterEnter) return "after";
  if (progress >= finderSnapThresholds.installEnter) return "install";
  return "before";
};

const applyFinderStage = (phase) => {
  const isBefore = phase === "before";
  const isInstall = phase === "install";
  const isAfter = phase === "after";

  featureSection.style.setProperty("--finder-progress", isBefore ? "0%" : "100%");
  featureSection.style.setProperty("--install-ring-progress", isBefore ? "0%" : "100%");
  featureSection.style.setProperty("--install-orb-opacity", isInstall ? "1" : "0");
  featureSection.style.setProperty("--install-scale", isInstall ? "1" : "0.84");
  featureSection.style.setProperty("--install-clip", isBefore ? "100%" : "0%");
  featureSection.style.setProperty("--after-opacity", isAfter ? "1" : "0");
  featureSection.style.setProperty("--before-scale", isAfter ? "1.018" : "1");
  featureSection.style.setProperty("--after-scale", isAfter ? "1" : "1.018");
  featureSection.style.setProperty("--lock-opacity", isBefore ? "1" : "0");
  featureSection.style.setProperty("--lock-scale", isBefore ? "1" : "0.92");
  featureSection.style.setProperty("--lock-rotate", isBefore ? "0deg" : "-32deg");

  featureSection.classList.toggle("is-finder-before", isBefore);
  featureSection.classList.toggle("is-finder-install", isInstall);
  featureSection.classList.toggle("is-finder-after", isAfter);
  featureSection.classList.toggle("is-install-complete", !isBefore);
};

const commitFinderStage = (phase) => {
  currentFinderStage = phase;
  pendingFinderStage = phase;
  applyFinderStage(phase);
};

const requestFinderStage = (phase) => {
  if (!featureSection) return;

  if (phase === currentFinderStage) {
    pendingFinderStage = phase;
    window.clearTimeout(finderSnapTimer);
    return;
  }

  if (phase !== pendingFinderStage) {
    pendingFinderStage = phase;
  }

  window.clearTimeout(finderSnapTimer);
  finderSnapTimer = window.setTimeout(() => {
    commitFinderStage(pendingFinderStage);
  }, finderSnapSettleMs);
};

const settleFinderStage = (progress) => {
  const phase = getFinderStage(progress);
  window.clearTimeout(finderSnapTimer);
  commitFinderStage(phase);
};

const updateFeatureScroll = () => {
  if (!featureSection || featureSteps.length === 0) return;

  const sectionRect = featureSection.getBoundingClientRect();
  const viewportHeight = window.innerHeight || document.documentElement.clientHeight || 1;
  const scrollRange = Math.max(1, sectionRect.height - viewportHeight);
  const progress = Math.min(1, Math.max(0, -sectionRect.top / scrollRange));
  const activeIndex = featureSegments.findIndex((segment, index) => {
    const isLast = index === featureSegments.length - 1;
    return progress >= segment.start && (isLast ? progress <= segment.end : progress < segment.end);
  });
  const safeActiveIndex = activeIndex === -1 ? featureSteps.length - 1 : activeIndex;
  const finderSegment = featureSegments[0];
  const finderProgress = progress > finderSegment.end ? 1 : clamp((progress - finderSegment.start) / (finderSegment.end - finderSegment.start));
  const phase = getFinderStage(finderProgress);

  featureSteps.forEach((step, index) => {
    step.classList.toggle("is-active", index === safeActiveIndex);
  });

  requestFinderStage(phase);
};

let featureScrollTicking = false;

const requestFeatureScrollUpdate = () => {
  if (featureScrollTicking) return;

  featureScrollTicking = true;
  window.requestAnimationFrame(() => {
    updateFeatureScroll();
    featureScrollTicking = false;
  });
};

if (featureSection) {
  commitFinderStage("before");
}

updateFeatureScroll();
window.addEventListener("scroll", requestFeatureScrollUpdate, { passive: true });
window.addEventListener("scrollend", () => {
  if (!featureSection) return;

  const sectionRect = featureSection.getBoundingClientRect();
  const viewportHeight = window.innerHeight || document.documentElement.clientHeight || 1;
  const scrollRange = Math.max(1, sectionRect.height - viewportHeight);
  const progress = Math.min(1, Math.max(0, -sectionRect.top / scrollRange));
  const finderSegment = featureSegments[0];
  const finderProgress = progress > finderSegment.end ? 1 : clamp((progress - finderSegment.start) / (finderSegment.end - finderSegment.start));

  settleFinderStage(finderProgress);
});
window.addEventListener("resize", requestFeatureScrollUpdate);
