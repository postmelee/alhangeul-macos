const faqItems = document.querySelectorAll(".faq-list details");
const featureSection = document.querySelector(".features-section");
const featureSteps = Array.from(document.querySelectorAll("[data-feature-step]"));
const revealGroups = Array.from(document.querySelectorAll("[data-reveal-group]"));
const stageLabelNodes = {
  start: document.querySelector('[data-stage-label="start"]'),
  middle: document.querySelector('[data-stage-label="middle"]'),
  end: document.querySelector('[data-stage-label="end"]'),
};

const featureStages = [
  {
    key: "finder",
    labels: ["기존 Mac", "알한글 설치", "Finder 썸네일"],
  },
  {
    key: "quicklook",
    labels: ["파일 선택", "알한글 설치", "스페이스바 미리보기"],
  },
  {
    key: "viewer",
    labels: ["HWP/HWPX 파일", "알한글 열기", "앱에서 보기"],
  },
  {
    key: "local",
    labels: ["문서 선택", "Mac에서 처리", "로컬 완료"],
  },
];

const checkpointsPerFeature = 3;
const finalCheckpointIndex = featureStages.length * checkpointsPerFeature - 1;
const checkpointProgress = {
  start: 1 / 6,
  middle: 1 / 2,
  end: 5 / 6,
};

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

const setupRevealAnimations = () => {
  revealGroups.forEach((group) => {
    Array.from(group.querySelectorAll("[data-reveal-item]")).forEach((item, index) => {
      item.style.setProperty("--reveal-index", index);
    });
  });

  if (revealGroups.length === 0) return;

  const revealAll = () => {
    revealGroups.forEach((group) => group.classList.add("is-revealed"));
  };

  const prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (prefersReducedMotion || !("IntersectionObserver" in window)) {
    revealAll();
    return;
  }

  const revealObserver = new IntersectionObserver(
    (entries, observer) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;

        entry.target.classList.add("is-revealed");
        observer.unobserve(entry.target);
      });
    },
    {
      threshold: 0.18,
      rootMargin: "0px 0px -12% 0px",
    },
  );

  revealGroups.forEach((group) => revealObserver.observe(group));
};

const getFeatureScrollState = () => {
  const sectionRect = featureSection.getBoundingClientRect();
  const viewportHeight = window.innerHeight || document.documentElement.clientHeight || 1;
  const scrollRange = Math.max(1, sectionRect.height - viewportHeight);
  const progress = clamp(-sectionRect.top / scrollRange);
  const globalCheckpoint = progress * finalCheckpointIndex;
  const activeIndex = Math.min(
    featureStages.length - 1,
    Math.floor(globalCheckpoint / checkpointsPerFeature),
  );
  const localCheckpoint = clamp(
    globalCheckpoint - activeIndex * checkpointsPerFeature,
    0,
    checkpointsPerFeature - 1,
  );

  return { activeIndex, localCheckpoint };
};

const getFeaturePhase = (timelineProgress) => {
  if (timelineProgress < checkpointProgress.start) return "entry";
  if (timelineProgress >= checkpointProgress.end) return "end";
  if (timelineProgress >= checkpointProgress.middle) return "middle";
  return "start";
};

const setStageLabels = (labels) => {
  stageLabelNodes.start.textContent = labels[0];
  stageLabelNodes.middle.textContent = labels[1];
  stageLabelNodes.end.textContent = labels[2];
};

const updateFeatureCards = (activeIndex) => {
  featureSteps.forEach((step, index) => {
    step.classList.toggle("is-active", index === activeIndex);
  });
};

const applyFeatureVisualState = (activeIndex, localCheckpoint) => {
  const feature = featureStages[activeIndex];
  const isFinder = feature.key === "finder";
  const timelineProgress = clamp(localCheckpoint / (checkpointsPerFeature - 1));
  const phase = getFeaturePhase(timelineProgress);
  const installProgress = clamp(
    (timelineProgress - checkpointProgress.start) /
      (checkpointProgress.middle - checkpointProgress.start),
  );
  const installEntry = smoothstep(
    checkpointProgress.start,
    checkpointProgress.start + 0.035,
    timelineProgress,
  );
  const installExit = 1 - smoothstep(0.58, 0.78, timelineProgress);
  const installOrbOpacity = installEntry * installExit;
  const installCheckProgress = smoothstep(0.88, 1, installProgress);
  const installLogoOpacity = 1 - smoothstep(0.68, 0.94, installProgress);
  const finderAfterOpacity = isFinder ? smoothstep(0.64, checkpointProgress.end, timelineProgress) : 0;
  const finderLockOpacity = isFinder
    ? timelineProgress <= checkpointProgress.start
      ? 1
      : 1 - smoothstep(
          checkpointProgress.start,
          checkpointProgress.start + 0.055,
          timelineProgress,
        )
    : 0;

  setStageLabels(feature.labels);

  featureSection.style.setProperty("--feature-progress", `${(timelineProgress * 100).toFixed(2)}%`);
  featureSection.style.setProperty("--install-ring-progress", `${(installProgress * 100).toFixed(2)}%`);
  featureSection.style.setProperty("--install-orb-opacity", installOrbOpacity.toFixed(3));
  featureSection.style.setProperty("--install-scale", (0.84 + installProgress * 0.16).toFixed(3));
  featureSection.style.setProperty("--install-clip", `${((1 - installProgress) * 100).toFixed(2)}%`);
  featureSection.style.setProperty("--install-logo-opacity", installLogoOpacity.toFixed(3));
  featureSection.style.setProperty("--install-check-opacity", installCheckProgress.toFixed(3));
  featureSection.style.setProperty("--install-check-scale", (0.72 + installCheckProgress * 0.28).toFixed(3));
  featureSection.style.setProperty("--install-check-dash", (1 - installCheckProgress).toFixed(3));
  featureSection.style.setProperty("--after-opacity", finderAfterOpacity.toFixed(3));
  featureSection.style.setProperty("--fallback-opacity", isFinder ? "0" : "1");
  featureSection.style.setProperty("--before-scale", (1 + finderAfterOpacity * 0.018).toFixed(3));
  featureSection.style.setProperty("--after-scale", (1.018 - finderAfterOpacity * 0.018).toFixed(3));
  featureSection.style.setProperty("--lock-opacity", finderLockOpacity.toFixed(3));
  featureSection.style.setProperty("--lock-scale", (0.92 + finderLockOpacity * 0.08).toFixed(3));
  featureSection.style.setProperty("--lock-rotate", `${(-32 * (1 - finderLockOpacity)).toFixed(2)}deg`);

  featureSection.classList.toggle("is-feature-finder", isFinder);
  featureSection.classList.toggle("is-feature-fallback", !isFinder);
  featureSection.classList.toggle("is-stage-start", phase === "start");
  featureSection.classList.toggle("is-stage-middle", phase === "middle");
  featureSection.classList.toggle("is-stage-end", phase === "end");
};

const updateFeatureScroll = () => {
  if (!featureSection || featureSteps.length === 0) return;

  const { activeIndex, localCheckpoint } = getFeatureScrollState();
  updateFeatureCards(activeIndex);
  applyFeatureVisualState(activeIndex, localCheckpoint);
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

setupRevealAnimations();
updateFeatureScroll();
window.addEventListener("scroll", requestFeatureScrollUpdate, { passive: true });
window.addEventListener("resize", requestFeatureScrollUpdate);
