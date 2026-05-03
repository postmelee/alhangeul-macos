const faqItems = document.querySelectorAll(".faq-list details");
const featureSection = document.querySelector(".features-section");
const featureSteps = Array.from(document.querySelectorAll("[data-feature-step]"));

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
  const activeIndex = Math.min(featureSteps.length - 1, Math.max(0, Math.round(progress * (featureSteps.length - 1))));
  const offset = `${(-28 * progress).toFixed(2)}%`;

  featureSection.style.setProperty("--feature-offset", offset);

  featureSteps.forEach((step, index) => {
    step.classList.toggle("is-active", index === activeIndex);
  });
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
