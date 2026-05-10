const faqItems = document.querySelectorAll(".faq-list details");
const featureSteps = Array.from(document.querySelectorAll("[data-feature-step]"));
const featureVideos = Array.from(document.querySelectorAll("[data-feature-video]"));
const revealGroups = Array.from(document.querySelectorAll("[data-reveal-group]"));
const prefersReducedMotionQuery = window.matchMedia("(prefers-reduced-motion: reduce)");

let activeFeatureIndex = 0;
let hasStartedFeaturePlayback = false;

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
  const sequenceIndexes = new Map();

  revealGroups.forEach((group) => {
    const sequenceKey = group.dataset.revealSequence;
    const revealGap = Number(group.dataset.revealGap) || 90;
    let sequenceIndex = sequenceKey ? sequenceIndexes.get(sequenceKey) || 0 : 0;

    Array.from(group.querySelectorAll("[data-reveal-item]")).forEach((item, index) => {
      const revealIndex = sequenceKey ? sequenceIndex : index;
      item.style.setProperty("--reveal-delay", `${revealIndex * revealGap}ms`);
      sequenceIndex += 1;
    });

    if (sequenceKey) {
      sequenceIndexes.set(sequenceKey, sequenceIndex);
    }
  });

  if (revealGroups.length === 0) return;

  const revealGroup = (group, observer) => {
    if (group.classList.contains("is-revealed")) return;

    group.classList.add("is-revealed");
    startFeaturePlaybackAfterReveal(group);
    if (observer) {
      observer.unobserve(group);
    }
  };

  const revealAll = () => {
    revealGroups.forEach((group) => revealGroup(group));
  };

  if (prefersReducedMotionQuery.matches || !("IntersectionObserver" in window)) {
    revealAll();
    return;
  }

  const revealObserver = new IntersectionObserver(
    (entries, observer) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;

        revealGroup(entry.target, observer);
      });
    },
    {
      threshold: 0.18,
      rootMargin: "0px 0px -12% 0px",
    },
  );

  revealGroups.forEach((group) => revealObserver.observe(group));
  window.setTimeout(() => {
    revealGroups.forEach((group) => {
      if (group.classList.contains("is-revealed")) return;

      const rect = group.getBoundingClientRect();
      const isVisible = rect.top < window.innerHeight && rect.bottom > 0;
      if (!isVisible) return;

      revealGroup(group, revealObserver);
    });
  }, 900);
};

const timeValueToMs = (value) => {
  const normalizedValue = value.trim();

  if (normalizedValue.endsWith("ms")) {
    return Number.parseFloat(normalizedValue) || 0;
  }

  if (normalizedValue.endsWith("s")) {
    return (Number.parseFloat(normalizedValue) || 0) * 1000;
  }

  return Number.parseFloat(normalizedValue) || 0;
};

const getLongestTransitionMs = (element) => {
  const style = window.getComputedStyle(element);
  const durations = style.transitionDuration.split(",").map(timeValueToMs);
  const delays = style.transitionDelay.split(",").map(timeValueToMs);
  const transitionCount = Math.max(durations.length, delays.length);

  return Math.max(
    ...Array.from({ length: transitionCount }, (_, index) => {
      const duration = durations[index % durations.length] || 0;
      const delay = delays[index % delays.length] || 0;
      return duration + delay;
    }),
  );
};

const startActiveFeaturePlayback = () => {
  if (hasStartedFeaturePlayback) return;

  hasStartedFeaturePlayback = true;
  activateFeature(activeFeatureIndex, { replay: true, play: true });
};

const startFeaturePlaybackAfterReveal = (group) => {
  if (!group.matches(".features-sticky") || hasStartedFeaturePlayback) return;

  const showcase = group.querySelector(".feature-showcase[data-reveal-item]");

  if (!showcase || prefersReducedMotionQuery.matches) {
    startActiveFeaturePlayback();
    return;
  }

  const fallbackDelay = getLongestTransitionMs(showcase) + 80;
  const startPlayback = () => startActiveFeaturePlayback();

  showcase.addEventListener("transitionend", startPlayback, { once: true });
  window.setTimeout(startPlayback, fallbackDelay);
};

const restartVideo = (video) => {
  try {
    video.currentTime = 0;
  } catch {
    // Some browsers can reject seeking before metadata is ready.
  }
};

const playVideo = (video) => {
  const playPromise = video.play();

  if (playPromise && typeof playPromise.catch === "function") {
    playPromise.catch(() => {});
  }
};

const activateFeature = (nextIndex, options = {}) => {
  const { replay = true, play = true } = options;
  const nextVideo = featureVideos[nextIndex];

  if (!nextVideo) return;

  activeFeatureIndex = nextIndex;

  featureSteps.forEach((step, index) => {
    const isActive = index === nextIndex;
    step.classList.toggle("is-active", isActive);
    step.setAttribute("aria-pressed", String(isActive));

    if (isActive && replay && !prefersReducedMotionQuery.matches) {
      step.classList.remove("is-highlight-animating");
      void step.offsetWidth;
      step.classList.add("is-highlight-animating");
    } else if (!isActive) {
      step.classList.remove("is-highlight-animating");
    }
  });

  featureVideos.forEach((video, index) => {
    const isActive = index === nextIndex;
    video.classList.toggle("is-active", isActive);
    video.setAttribute("aria-hidden", String(!isActive));

    if (!isActive) {
      video.pause();
      return;
    }

    if (replay) {
      restartVideo(video);
    }

    if (!play || prefersReducedMotionQuery.matches) {
      video.pause();
    } else {
      playVideo(video);
    }
  });
};

const setupFeatureShowcase = () => {
  if (featureSteps.length === 0 || featureVideos.length === 0) return;

  featureSteps.forEach((step, index) => {
    const replayFeature = () => activateFeature(index);

    step.addEventListener("mouseenter", replayFeature);
    step.addEventListener("focus", replayFeature);
    step.addEventListener("click", replayFeature);
  });

  activateFeature(0, { replay: false, play: false });

  prefersReducedMotionQuery.addEventListener("change", () => {
    activateFeature(activeFeatureIndex, { replay: false, play: hasStartedFeaturePlayback });
  });
};

setupFeatureShowcase();
setupRevealAnimations();
