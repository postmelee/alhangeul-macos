const faqItems = document.querySelectorAll(".faq-list details");
const featureSteps = Array.from(document.querySelectorAll("[data-feature-step]"));
const featureVideos = Array.from(document.querySelectorAll("[data-feature-video]"));
const revealGroups = Array.from(document.querySelectorAll("[data-reveal-group]"));
const prefersReducedMotionQuery = window.matchMedia("(prefers-reduced-motion: reduce)");

let activeFeatureIndex = 0;

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

  const revealAll = () => {
    revealGroups.forEach((group) => group.classList.add("is-revealed"));
  };

  if (prefersReducedMotionQuery.matches || !("IntersectionObserver" in window)) {
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
  window.setTimeout(() => {
    revealGroups.forEach((group) => {
      if (group.classList.contains("is-revealed")) return;

      const rect = group.getBoundingClientRect();
      const isVisible = rect.top < window.innerHeight && rect.bottom > 0;
      if (!isVisible) return;

      group.classList.add("is-revealed");
      revealObserver.unobserve(group);
    });
  }, 900);
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
  const { replay = true } = options;
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

    if (prefersReducedMotionQuery.matches) {
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

  activateFeature(0, { replay: false });

  prefersReducedMotionQuery.addEventListener("change", () => {
    activateFeature(activeFeatureIndex, { replay: false });
  });
};

setupRevealAnimations();
setupFeatureShowcase();
