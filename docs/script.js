const faqItems = document.querySelectorAll(".faq-list details");
const featureSection = document.querySelector(".features-section");
const featureSteps = Array.from(document.querySelectorAll("[data-feature-step]"));
const featureSegments = [
  { start: 0, end: 0.82 },
  { start: 0.82, end: 0.9 },
  { start: 0.9, end: 0.96 },
  { start: 0.96, end: 1 },
];

const clamp = (value, min = 0, max = 1) => Math.min(max, Math.max(min, value));

const smoothstep = (edgeStart, edgeEnd, value) => {
  const progress = clamp((value - edgeStart) / (edgeEnd - edgeStart || 1));
  return progress * progress * (3 - 2 * progress);
};

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
  const installProgress = smoothstep(0.2, 0.7, finderProgress);
  const afterOpacity = smoothstep(0.68, 0.96, finderProgress);
  const lockOpacity = 1 - smoothstep(0.42, 0.72, finderProgress);
  const installOrbOpacity = smoothstep(0.16, 0.42, finderProgress) * (1 - smoothstep(0.9, 1, finderProgress) * 0.18);
  const phase = finderProgress < 0.28 ? "before" : finderProgress < 0.82 ? "install" : "after";

  featureSection.style.setProperty("--finder-progress", `${(finderProgress * 100).toFixed(2)}%`);
  featureSection.style.setProperty("--install-progress", installProgress.toFixed(3));
  featureSection.style.setProperty("--install-orb-opacity", installOrbOpacity.toFixed(3));
  featureSection.style.setProperty("--install-scale", (0.78 + installProgress * 0.22).toFixed(3));
  featureSection.style.setProperty("--install-clip", `${((1 - installProgress) * 100).toFixed(2)}%`);
  featureSection.style.setProperty("--after-opacity", afterOpacity.toFixed(3));
  featureSection.style.setProperty("--before-scale", (1 + afterOpacity * 0.018).toFixed(3));
  featureSection.style.setProperty("--after-scale", (1.018 - afterOpacity * 0.018).toFixed(3));
  featureSection.style.setProperty("--lock-opacity", lockOpacity.toFixed(3));
  featureSection.style.setProperty("--lock-scale", (1 - installProgress * 0.08).toFixed(3));
  featureSection.style.setProperty("--lock-rotate", `${(-32 * installProgress).toFixed(2)}deg`);

  featureSteps.forEach((step, index) => {
    step.classList.toggle("is-active", index === safeActiveIndex);
  });

  featureSection.classList.toggle("is-finder-before", phase === "before");
  featureSection.classList.toggle("is-finder-install", phase === "install");
  featureSection.classList.toggle("is-finder-after", phase === "after");
  featureSection.classList.toggle("is-install-complete", installProgress > 0.96);
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
