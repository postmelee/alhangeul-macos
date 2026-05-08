const faqItems = document.querySelectorAll(".faq-list details");
const featureSection = document.querySelector(".features-section");
const finderThumbnailVideo = document.querySelector("[data-finder-thumbnail-video]");
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
    labels: ["파일 선택", "스페이스바 미리보기", "확대 및 복사"],
  },
  {
    key: "viewer",
    labels: ["HWP/HWPX 파일 열기", "편집하기", "저장하기"],
  },
  {
    key: "local",
    labels: ["PDF 내보내기", "공유하기", "인쇄하기"],
  },
];

const checkpointsPerFeature = 3;
const featureScrollSpan = checkpointsPerFeature;
const finalCheckpointIndex = featureStages.length * featureScrollSpan;
const checkpointProgress = {
  start: 1 / 6,
  middle: 1 / 2,
  end: 5 / 6,
};
const progressMap = [
  [0, 0],
  [0.25, checkpointProgress.start],
  [0.5, checkpointProgress.middle],
  [0.75, checkpointProgress.end],
  [1, 1],
];
const quicklookPopupShadowOpacity = 0.18;
const quicklookScrollSteps = [
  { key: "scroll1", start: 0.25, end: 0.31 },
  { key: "scroll2", start: 0.5, end: 0.56 },
  { key: "scroll3", start: 0.75, end: 0.81 },
  { key: "scroll4", start: 0.94, end: 1 },
];

const clamp = (value, min = 0, max = 1) => Math.min(max, Math.max(min, value));
const step = (edge, value) => (value >= edge ? 1 : 0);

const smoothstep = (edgeStart, edgeEnd, value) => {
  const progress = clamp((value - edgeStart) / (edgeEnd - edgeStart || 1));
  return progress * progress * (3 - 2 * progress);
};

const easeOutFast = (edgeStart, edgeEnd, value) => {
  const progress = clamp((value - edgeStart) / (edgeEnd - edgeStart || 1));
  return 1 - Math.pow(1 - progress, 3);
};

let latestFinderVideoProgress = 0;

const syncFinderThumbnailVideo = (progress) => {
  if (!finderThumbnailVideo) return;

  latestFinderVideoProgress = clamp(progress);

  if (!Number.isFinite(finderThumbnailVideo.duration) || finderThumbnailVideo.duration <= 0) {
    return;
  }

  const targetTime = latestFinderVideoProgress * finderThumbnailVideo.duration;
  if (Math.abs(finderThumbnailVideo.currentTime - targetTime) > 0.035) {
    finderThumbnailVideo.currentTime = targetTime;
  }
};

finderThumbnailVideo?.addEventListener("loadedmetadata", () => {
  syncFinderThumbnailVideo(latestFinderVideoProgress);
});

const mapScrollProgressToVisualProgress = (progress) => {
  const clampedProgress = clamp(progress);

  for (let index = 1; index < progressMap.length; index += 1) {
    const [previousScroll, previousVisual] = progressMap[index - 1];
    const [nextScroll, nextVisual] = progressMap[index];

    if (clampedProgress <= nextScroll) {
      const segmentProgress = clamp(
        (clampedProgress - previousScroll) / (nextScroll - previousScroll),
      );

      return previousVisual + (nextVisual - previousVisual) * segmentProgress;
    }
  }

  return 1;
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
  window.setTimeout(revealAll, 900);
};

const getFeatureScrollState = () => {
  const sectionRect = featureSection.getBoundingClientRect();
  const viewportHeight = window.innerHeight || document.documentElement.clientHeight || 1;
  const scrollRange = Math.max(1, sectionRect.height - viewportHeight);
  const progress = clamp(-sectionRect.top / scrollRange);
  const globalCheckpoint = progress * finalCheckpointIndex;
  const activeIndex = Math.min(
    featureStages.length - 1,
    Math.floor(globalCheckpoint / featureScrollSpan),
  );
  const localCheckpoint = clamp(
    globalCheckpoint - activeIndex * featureScrollSpan,
    0,
    featureScrollSpan,
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
  const isQuickLook = feature.key === "quicklook";
  const isViewer = feature.key === "viewer";
  const isMacShare = feature.key === "local";
  const scrollProgress = clamp(localCheckpoint / featureScrollSpan);
  const timelineProgress = mapScrollProgressToVisualProgress(scrollProgress);
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
  const installOrbOpacity = isFinder ? installEntry * installExit : 0;
  const installCheckProgress = smoothstep(0.88, 1, installProgress);
  const installLogoOpacity = 1 - smoothstep(0.68, 0.94, installProgress);
  const finderAfterOpacity = isFinder
    ? smoothstep(0.64, checkpointProgress.end, timelineProgress)
    : isQuickLook
      ? 1
      : 0;
  const finderLockOpacity = isFinder
    ? timelineProgress <= checkpointProgress.start
      ? 1
      : 1 - smoothstep(
          checkpointProgress.start,
          checkpointProgress.start + 0.055,
          timelineProgress,
        )
    : 0;
  const quicklookClickedOpacity = isQuickLook
    ? smoothstep(0.025, checkpointProgress.start, timelineProgress)
    : isViewer
      ? 1
      : 0;
  const quicklookPreviewEntry = isQuickLook
    ? easeOutFast(checkpointProgress.middle - 0.045, checkpointProgress.middle - 0.006, timelineProgress)
    : 0;
  const quicklookPreviewOpacity = quicklookPreviewEntry;
  const quicklookScrollProgress = isQuickLook
    ? clamp(
        (timelineProgress - checkpointProgress.middle) /
          (checkpointProgress.end - checkpointProgress.middle),
      )
    : 0;
  const quicklookScrollOpacities = quicklookScrollSteps.map(({ start, end }) =>
    easeOutFast(start, end, quicklookScrollProgress),
  );
  const quicklookDimOpacity = isQuickLook
    ? Math.max(quicklookPreviewEntry * 0.38, Math.max(...quicklookScrollOpacities) * 0.34)
    : 0;
  const quicklookShadowOpacities = {
    preview: 0,
    scroll1: 0,
    scroll2: 0,
    scroll3: 0,
    scroll4: 0,
  };

  if (isQuickLook && quicklookPreviewOpacity > 0) {
    let activeShadowKey = "preview";

    quicklookScrollSteps.forEach(({ key, start }) => {
      if (quicklookScrollProgress >= start) {
        activeShadowKey = key;
      }
    });

    quicklookShadowOpacities[activeShadowKey] = quicklookPopupShadowOpacity;
  }

  const viewerFrameOpacities = Array.from({ length: 11 }, () => 0);
  const viewerOpenProgress = isViewer
    ? easeOutFast(checkpointProgress.start - 0.025, checkpointProgress.start + 0.055, timelineProgress)
    : 0;
  const viewerTypingStart = checkpointProgress.start +
    (checkpointProgress.middle - checkpointProgress.start) * 0.2;
  const viewerTypingProgress = isViewer
    ? clamp(
        (timelineProgress - viewerTypingStart) /
          (checkpointProgress.middle - viewerTypingStart),
      )
    : 0;
  const viewerTypingFrame = viewerTypingProgress > 0
    ? Math.max(1, Math.min(10, Math.ceil(viewerTypingProgress * 10)))
    : 0;
  const viewerCommandEntry = isViewer
    ? easeOutFast(checkpointProgress.middle + 0.015, checkpointProgress.middle + 0.075, timelineProgress)
    : 0;
  const viewerCommandOpacity = isViewer
    ? viewerCommandEntry *
      (1 - smoothstep(checkpointProgress.middle + 0.14, checkpointProgress.middle + 0.22, timelineProgress))
    : 0;
  const viewerSaveProgress = isViewer
    ? clamp(
        (timelineProgress - checkpointProgress.middle) /
          (checkpointProgress.end - checkpointProgress.middle),
      )
    : 0;
  const viewerSaveAskOpacity = isViewer
    ? easeOutFast(0.36, 0.52, viewerSaveProgress) *
      (1 - smoothstep(0.72, 0.88, viewerSaveProgress))
    : 0;
  const viewerSaveCompleteOpacity = isViewer
    ? easeOutFast(0.86, 1, viewerSaveProgress)
    : 0;
  const viewerSaveBadgeProgress = isViewer
    ? easeOutFast(0.9, 1, viewerSaveProgress)
    : 0;

  if (isViewer && viewerOpenProgress > 0) {
    viewerFrameOpacities[viewerTypingFrame] = viewerOpenProgress;
  }

  const shareStageProgress = isMacShare ? timelineProgress : 0;
  const sharePdfSegment = checkpointProgress.start;
  const shareExportSegment = checkpointProgress.middle - checkpointProgress.start;
  const shareFinalSegment = checkpointProgress.end - checkpointProgress.middle;
  const sharePdfAfterComplete = sharePdfSegment / 3;
  const sharePdfPopupStart = sharePdfSegment * 2 / 3;
  const sharePdfPopupHoldEnd = checkpointProgress.start + shareExportSegment * 0.22;
  const sharePdfPopupExitComplete = checkpointProgress.start + shareExportSegment / 3;
  const shareBackgroundFadeStart = checkpointProgress.start + shareExportSegment * 0.04;
  const shareBackgroundFadeComplete = checkpointProgress.start + shareExportSegment * 0.2;
  const sharePdfExitProgress = isMacShare
    ? smoothstep(shareBackgroundFadeStart, shareBackgroundFadeComplete, shareStageProgress)
    : 0;
  const shareAfterSwitchAt = sharePdfPopupExitComplete + shareExportSegment * 0.16;
  const sharePopupStart = shareAfterSwitchAt + shareExportSegment * 0.12;
  const sharePopupHoldEnd = checkpointProgress.middle + shareFinalSegment * 0.1;
  const sharePopupExitComplete = checkpointProgress.middle + shareFinalSegment / 3;
  const shareFinalSwitchAt = sharePopupExitComplete;
  const sharePdfAfterEntry = isMacShare
    ? smoothstep(0, sharePdfAfterComplete, shareStageProgress)
    : 0;
  const shareBeforeEntry = isMacShare
    ? smoothstep(shareBackgroundFadeStart, shareBackgroundFadeComplete, shareStageProgress)
    : 0;
  const sharePdfBeforeOpacity = isMacShare ? 1 - sharePdfAfterEntry : 0;
  const sharePdfAfterOpacity = isMacShare
    ? sharePdfAfterEntry * (1 - sharePdfExitProgress)
    : 0;
  const sharePdfPopupOpacity = isMacShare
    ? easeOutFast(sharePdfPopupStart, checkpointProgress.start, shareStageProgress) *
      (1 - smoothstep(sharePdfPopupHoldEnd, sharePdfPopupExitComplete, shareStageProgress))
    : 0;
  const shareBeforeOpacity = isMacShare
    ? shareBeforeEntry *
      (1 - step(shareAfterSwitchAt, shareStageProgress))
    : 0;
  const shareAfterOpacity = isMacShare
    ? step(shareAfterSwitchAt, shareStageProgress) *
      (1 - step(shareFinalSwitchAt, shareStageProgress))
    : 0;
  const shareEmailPopupOpacity = isMacShare
    ? easeOutFast(sharePopupStart, checkpointProgress.middle, shareStageProgress) *
      (1 - smoothstep(sharePopupHoldEnd, sharePopupExitComplete, shareStageProgress))
    : 0;
  const shareFinalBaseOpacity = isMacShare
    ? step(shareFinalSwitchAt, shareStageProgress)
    : 0;
  const sharePrintPopupOpacity = isMacShare
    ? easeOutFast(checkpointProgress.end - 0.05, checkpointProgress.end - 0.006, shareStageProgress)
    : 0;
  const shareBaseShadowOpacity = isMacShare
    ? Math.max(sharePdfAfterEntry, shareBeforeOpacity, shareAfterOpacity, shareFinalBaseOpacity)
    : 0;

  syncFinderThumbnailVideo(isFinder ? scrollProgress : 0);

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
  featureSection.style.setProperty("--fallback-opacity", isFinder || isQuickLook || isViewer || isMacShare ? "0" : "1");
  featureSection.style.setProperty("--quicklook-clicked-opacity", quicklookClickedOpacity.toFixed(3));
  featureSection.style.setProperty("--quicklook-dim-opacity", quicklookDimOpacity.toFixed(3));
  featureSection.style.setProperty("--quicklook-preview-opacity", quicklookPreviewOpacity.toFixed(3));
  featureSection.style.setProperty("--quicklook-preview-shadow", quicklookShadowOpacities.preview.toFixed(3));
  quicklookScrollOpacities.forEach((opacity, index) => {
    featureSection.style.setProperty(`--quicklook-scroll-${index + 1}-opacity`, opacity.toFixed(3));
  });
  featureSection.style.setProperty("--quicklook-scroll-1-shadow", quicklookShadowOpacities.scroll1.toFixed(3));
  featureSection.style.setProperty("--quicklook-scroll-2-shadow", quicklookShadowOpacities.scroll2.toFixed(3));
  featureSection.style.setProperty("--quicklook-scroll-3-shadow", quicklookShadowOpacities.scroll3.toFixed(3));
  featureSection.style.setProperty("--quicklook-scroll-4-shadow", quicklookShadowOpacities.scroll4.toFixed(3));
  viewerFrameOpacities.forEach((opacity, index) => {
    featureSection.style.setProperty(`--viewer-frame-${index}-opacity`, opacity.toFixed(3));
  });
  featureSection.style.setProperty("--viewer-frame-y", "0px");
  featureSection.style.setProperty("--viewer-frame-scale", "1");
  featureSection.style.setProperty("--viewer-command-opacity", viewerCommandOpacity.toFixed(3));
  featureSection.style.setProperty("--viewer-command-scale", (0.94 + viewerCommandEntry * 0.06).toFixed(3));
  featureSection.style.setProperty("--viewer-save-ask-opacity", viewerSaveAskOpacity.toFixed(3));
  featureSection.style.setProperty("--viewer-save-complete-opacity", viewerSaveCompleteOpacity.toFixed(3));
  featureSection.style.setProperty("--viewer-save-badge-opacity", viewerSaveBadgeProgress.toFixed(3));
  featureSection.style.setProperty("--viewer-save-badge-scale", (0.86 + viewerSaveBadgeProgress * 0.14).toFixed(3));
  featureSection.style.setProperty("--viewer-save-check-dash", (1 - viewerSaveBadgeProgress).toFixed(3));
  featureSection.style.setProperty("--before-opacity", isFinder ? "1" : "0");
  featureSection.style.setProperty("--share-pdf-before-opacity", sharePdfBeforeOpacity.toFixed(3));
  featureSection.style.setProperty("--share-pdf-after-opacity", sharePdfAfterOpacity.toFixed(3));
  featureSection.style.setProperty("--share-pdf-popup-opacity", sharePdfPopupOpacity.toFixed(3));
  featureSection.style.setProperty("--share-base-shadow-opacity", shareBaseShadowOpacity.toFixed(3));
  featureSection.style.setProperty("--share-before-opacity", shareBeforeOpacity.toFixed(3));
  featureSection.style.setProperty("--share-after-opacity", shareAfterOpacity.toFixed(3));
  featureSection.style.setProperty("--share-email-popup-opacity", shareEmailPopupOpacity.toFixed(3));
  featureSection.style.setProperty("--share-final-base-opacity", shareFinalBaseOpacity.toFixed(3));
  featureSection.style.setProperty("--share-print-popup-opacity", sharePrintPopupOpacity.toFixed(3));
  featureSection.style.setProperty("--before-scale", (1 + finderAfterOpacity * 0.018).toFixed(3));
  featureSection.style.setProperty("--after-scale", (1.018 - finderAfterOpacity * 0.018).toFixed(3));
  featureSection.style.setProperty("--lock-opacity", finderLockOpacity.toFixed(3));
  featureSection.style.setProperty("--lock-scale", (0.92 + finderLockOpacity * 0.08).toFixed(3));
  featureSection.style.setProperty("--lock-rotate", `${(-32 * (1 - finderLockOpacity)).toFixed(2)}deg`);

  featureSection.classList.toggle("is-feature-finder", isFinder);
  featureSection.classList.toggle("is-feature-quicklook", isQuickLook);
  featureSection.classList.toggle("is-feature-viewer", isViewer);
  featureSection.classList.toggle("is-feature-share", isMacShare);
  featureSection.classList.toggle("is-feature-fallback", !isFinder && !isQuickLook && !isViewer && !isMacShare);
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
