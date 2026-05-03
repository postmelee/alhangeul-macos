const faqItems = document.querySelectorAll(".faq-list details");
const featureSection = document.querySelector(".features-section");
const featureSteps = Array.from(document.querySelectorAll("[data-feature-step]"));
const featureSegments = [
  { start: 0, end: 0.72 },
  { start: 0.72, end: 0.82 },
  { start: 0.82, end: 0.92 },
  { start: 0.92, end: 1 },
];

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

const getFinderStage = (progress) => {
  if (progress <= 0.012) return "before";
  if (progress < 0.34) return "install";
  return "after";
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

  featureSteps.forEach((step, index) => {
    step.classList.toggle("is-active", index === safeActiveIndex);
  });

  featureSection.classList.toggle("is-finder-before", phase === "before");
  featureSection.classList.toggle("is-finder-install", phase === "install");
  featureSection.classList.toggle("is-finder-after", phase === "after");
  featureSection.classList.toggle("is-install-complete", !isBefore);
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

updateFeatureScroll();
window.addEventListener("scroll", requestFeatureScrollUpdate, { passive: true });
window.addEventListener("resize", requestFeatureScrollUpdate);
