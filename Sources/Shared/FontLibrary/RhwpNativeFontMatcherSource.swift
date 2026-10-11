// 생성 파일: scripts/build-native-font-matcher.mjs. 직접 수정 금지.
// rhwp 1a76570e833917d15817415a53c09ad61ab3203f, esbuild 0.25.12
enum RhwpNativeFontMatcherSource {
    static let commit = "1a76570e833917d15817415a53c09ad61ab3203f"
    static let sha256 = "2cfbdf0ddc3c3748b44bd66c3aaa8b262834b4479f5cb51fd9d6c58a798acb60"
    static let script = #"""
(() => {
  var __defProp = Object.defineProperty;
  var __defNormalProp = (obj, key2, value) => key2 in obj ? __defProp(obj, key2, { enumerable: true, configurable: true, writable: true, value }) : obj[key2] = value;
  var __publicField = (obj, key2, value) => __defNormalProp(obj, typeof key2 !== "symbol" ? key2 + "" : key2, value);

  // build.noindex/task567/stage3-2/upstream-v087/rhwp-studio/src/core/host-font-provider.ts
  var MAX_FACES = 25e3;
  var MAX_FONT_BYTES = 64 * 1024 * 1024;
  function validName(value, allowEmpty = false) {
    return typeof value === "string" && value.length <= 1024 && (allowEmpty || value.trim().length > 0);
  }
  function copySnapshot(value) {
    if (!value || !validName(value.revision) || !Array.isArray(value.faces) || value.faces.length > MAX_FACES) {
      throw new Error("Invalid host font snapshot");
    }
    const ids = /* @__PURE__ */ new Set();
    const faces = value.faces.map((face) => {
      if (!face || !validName(face.id) || ids.has(face.id) || !validName(face.family) || !validName(face.fullName) || !validName(face.postscriptName, true) || !validName(face.style, true) || face.weight !== void 0 && (!Number.isFinite(face.weight) || face.weight < 1 || face.weight > 1e3) || face.slant !== void 0 && !["normal", "italic", "oblique"].includes(face.slant) || face.aliases !== void 0 && (!Array.isArray(face.aliases) || face.aliases.length > 32 || !face.aliases.every((alias) => validName(alias)))) {
        throw new Error("Invalid host font face");
      }
      ids.add(face.id);
      return Object.freeze({
        id: face.id,
        family: face.family,
        fullName: face.fullName,
        postscriptName: face.postscriptName,
        style: face.style,
        aliases: Object.freeze([...face.aliases ?? []]),
        weight: face.weight,
        slant: face.slant
      });
    });
    return Object.freeze({ revision: value.revision, faces: Object.freeze(faces) });
  }
  var HostFontSource = class {
    constructor() {
      __publicField(this, "provider", null);
      __publicField(this, "off", null);
      __publicField(this, "controller", new AbortController());
      __publicField(this, "epoch", 0);
      __publicField(this, "connection", 0);
      __publicField(this, "snapshot", null);
      __publicField(this, "refs", []);
      __publicField(this, "pendingSnapshot", null);
      __publicField(this, "pendingBytes", /* @__PURE__ */ new Map());
      __publicField(this, "listeners", /* @__PURE__ */ new Set());
      __publicField(this, "error", null);
    }
    get active() {
      return this.provider !== null;
    }
    get generation() {
      return this.epoch;
    }
    get lastError() {
      return this.error;
    }
    subscribe(listener) {
      this.listeners.add(listener);
      return () => {
        this.listeners.delete(listener);
      };
    }
    notify() {
      for (const listener of this.listeners) listener();
    }
    invalidate() {
      this.controller.abort();
      this.controller = new AbortController();
      this.epoch += 1;
      this.snapshot = null;
      this.refs = [];
      this.pendingSnapshot = null;
      this.pendingBytes.clear();
      this.error = null;
    }
    async setProvider(provider) {
      const connection = ++this.connection;
      const off = this.off;
      this.off = null;
      this.provider = provider;
      this.invalidate();
      try {
        off?.();
      } catch (error) {
        console.warn("[HostFonts] Unsubscribe failed:", error);
      }
      if (provider) {
        try {
          const unsubscribe = provider.subscribe(() => {
            if (this.connection !== connection) return;
            this.invalidate();
            this.notify();
            void this.ready();
          });
          if (typeof unsubscribe !== "function") throw new Error("Host font subscribe must return a disposer");
          this.off = unsubscribe;
        } catch (error) {
          this.error = String(error);
        }
      }
      this.notify();
      await this.ready();
    }
    ready() {
      if (!this.provider || this.snapshot || this.error !== null) return Promise.resolve();
      if (this.pendingSnapshot) return this.pendingSnapshot;
      const provider = this.provider;
      const generation = this.epoch;
      const signal = this.controller.signal;
      const pending = Promise.resolve().then(() => provider.getSnapshot(signal)).then((value) => {
        if (signal.aborted || generation !== this.epoch) return;
        this.snapshot = copySnapshot(value);
        this.refs = Object.freeze(this.snapshot.faces.map((face) => Object.freeze({
          key: JSON.stringify(["host", this.epoch, this.snapshot.revision, face.id]),
          face,
          revision: this.snapshot.revision,
          generation: this.epoch
        })));
        this.error = null;
      }).catch((error) => {
        if (!signal.aborted && generation === this.epoch) this.error = String(error);
      }).finally(() => {
        if (this.pendingSnapshot === pending) {
          this.pendingSnapshot = null;
        }
      });
      this.pendingSnapshot = pending;
      return pending;
    }
    references() {
      return this.refs;
    }
    read(reference) {
      const provider = this.provider;
      const signal = this.controller.signal;
      if (!provider || reference.generation !== this.epoch || reference.revision !== this.snapshot?.revision || !this.snapshot.faces.some((face) => face === reference.face)) return Promise.resolve(null);
      const existing = this.pendingBytes.get(reference.key);
      if (existing) return existing;
      const pending = Promise.resolve().then(() => provider.readFace(reference.face.id, reference.revision, signal)).then((data) => {
        if (signal.aborted || reference.generation !== this.epoch) return null;
        if (!(data?.bytes instanceof ArrayBuffer) || data.bytes.byteLength === 0 || data.bytes.byteLength > MAX_FONT_BYTES || !Number.isSafeInteger(data.faceIndex ?? 0) || (data.faceIndex ?? 0) < 0) return null;
        return { bytes: data.bytes.slice(0), faceIndex: data.faceIndex ?? 0 };
      }, () => null).finally(() => {
        if (this.pendingBytes.get(reference.key) === pending) this.pendingBytes.delete(reference.key);
      });
      this.pendingBytes.set(reference.key, pending);
      return pending;
    }
  };

  // build.noindex/task567/stage3-2/upstream-v087/rhwp-studio/src/core/generated/font-rule-projections/canvas2d-paint.ts
  var FONT_RULE_CANVAS2D_PAINT_META = Object.freeze({
    "schemaVersion": "1.0",
    "sourceCommit": "a1f9872e28aea6755b656161ed1802f73308da58",
    "inputSha256": "936b45bdd1ca4c319f23620ba87adf696278bf214a21a678a91c768547d13796",
    "projectionId": "canvas2d-paint",
    "projectionSha256": "c959e68087f6928edcafc74a1d3f9cd3885dd7540faf22b7663a49b6ad8835e4",
    "ruleCount": 281
  });
  var FONT_RULE_CANVAS2D_PAINT_RULES = Object.freeze([
    {
      "ruleId": "rule.rust-paint-chain.e00c9b26ff77a9a990aa",
      "sourceBoundaryId": "rust-paint-chain.installed-aliases",
      "relationType": "official-successor",
      "decisionPlane": "paint",
      "sourceFace": "\uC815\uBD80\uC0C1\uC9D5 \uBD80\uCC98\uBA85_16040911",
      "targetFaceOrPolicy": "ROKG",
      "conditions": {
        "availability": "exact-source-unavailable"
      },
      "order": 0,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.rust-paint-chain.b4d532ad95d211fc126d",
      "sourceBoundaryId": "rust-paint-chain.installed-aliases",
      "relationType": "official-successor",
      "decisionPlane": "paint",
      "sourceFace": "\uC815\uBD80\uC0C1\uC9D5 \uBD80\uCC98\uBA85_16040911",
      "targetFaceOrPolicy": "ROKG R",
      "conditions": {
        "availability": "exact-source-unavailable"
      },
      "order": 1,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.rust-paint-chain.51b791ee51c34eaf8111",
      "sourceBoundaryId": "rust-paint-chain.installed-aliases",
      "relationType": "official-successor",
      "decisionPlane": "paint",
      "sourceFace": "\uC815\uBD80\uC0C1\uC9D5 \uBD80\uCC98\uBA85_16040911",
      "targetFaceOrPolicy": "\uB300\uD55C\uBBFC\uAD6D\uC815\uBD80\uC0C1\uC9D5\uCCB4",
      "conditions": {
        "availability": "exact-source-unavailable"
      },
      "order": 2,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.rust-paint-chain.a32a4fc414ef08d18dbe",
      "sourceBoundaryId": "rust-paint-chain.installed-aliases",
      "relationType": "official-successor",
      "decisionPlane": "paint",
      "sourceFace": "\uC815\uBD80\uC0C1\uC9D5 \uBD80\uCC98\uBA85_16040911",
      "targetFaceOrPolicy": "\uB300\uD55C\uBBFC\uAD6D\uC815\uBD80\uC0C1\uC9D5\uCCB4 R",
      "conditions": {
        "availability": "exact-source-unavailable"
      },
      "order": 3,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.rust-paint-chain.b26ec7001aaf437c8556",
      "sourceBoundaryId": "rust-paint-chain.installed-aliases",
      "relationType": "official-successor",
      "decisionPlane": "paint",
      "sourceFace": "\uC815\uBD80\uC0C1\uC9D5 \uBD80\uCC98\uBA85_16040911",
      "targetFaceOrPolicy": "ROKGR",
      "conditions": {
        "availability": "exact-source-unavailable"
      },
      "order": 4,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.rust-paint-chain.bdaf3df068763d38cbe4",
      "sourceBoundaryId": "rust-paint-chain.installed-aliases",
      "relationType": "official-successor",
      "decisionPlane": "paint",
      "sourceFace": "Government_16040911",
      "targetFaceOrPolicy": "ROKG",
      "conditions": {
        "availability": "exact-source-unavailable"
      },
      "order": 0,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.rust-paint-chain.13dccfb7e2e3ac8b4c95",
      "sourceBoundaryId": "rust-paint-chain.installed-aliases",
      "relationType": "official-successor",
      "decisionPlane": "paint",
      "sourceFace": "Government_16040911",
      "targetFaceOrPolicy": "ROKG R",
      "conditions": {
        "availability": "exact-source-unavailable"
      },
      "order": 1,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.rust-paint-chain.18e0090dc39ca5982f48",
      "sourceBoundaryId": "rust-paint-chain.installed-aliases",
      "relationType": "official-successor",
      "decisionPlane": "paint",
      "sourceFace": "Government_16040911",
      "targetFaceOrPolicy": "\uB300\uD55C\uBBFC\uAD6D\uC815\uBD80\uC0C1\uC9D5\uCCB4",
      "conditions": {
        "availability": "exact-source-unavailable"
      },
      "order": 2,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.rust-paint-chain.d42ea8ed9ffa1f3b3963",
      "sourceBoundaryId": "rust-paint-chain.installed-aliases",
      "relationType": "official-successor",
      "decisionPlane": "paint",
      "sourceFace": "Government_16040911",
      "targetFaceOrPolicy": "\uB300\uD55C\uBBFC\uAD6D\uC815\uBD80\uC0C1\uC9D5\uCCB4 R",
      "conditions": {
        "availability": "exact-source-unavailable"
      },
      "order": 3,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.rust-paint-chain.e2ccc6ad363c6c774e86",
      "sourceBoundaryId": "rust-paint-chain.installed-aliases",
      "relationType": "official-successor",
      "decisionPlane": "paint",
      "sourceFace": "Government_16040911",
      "targetFaceOrPolicy": "ROKGR",
      "conditions": {
        "availability": "exact-source-unavailable"
      },
      "order": 4,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.31018655d8b0949f8169",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD734\uBA3C\uBA85\uC870",
      "targetFaceOrPolicy": "\uD734\uBA3C\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.d1128911d36a5d57e02d",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD734\uBA3C\uBA85\uC870",
      "targetFaceOrPolicy": "HY\uC2E0\uBA85\uC870",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.917ee2221fd0ba861e44",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uC591\uC911\uACE0\uB515",
      "targetFaceOrPolicy": "HY\uC911\uACE0\uB515",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.082d013155cb2f1231ad",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uC591\uC2E0\uBA85\uC870",
      "targetFaceOrPolicy": "HY\uC2E0\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.674bc70d924bf5707bcf",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uBA85\uC870",
      "targetFaceOrPolicy": "HY\uACAC\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": 0,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.3f0c7dac166d031c86c0",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC2E0\uBA85 \uD0DC\uACE0\uB515",
      "targetFaceOrPolicy": "HY\uC911\uACE0\uB515",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.55303f02912f1e4b25db",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uC591\uACAC\uBA85\uC870",
      "targetFaceOrPolicy": "HY\uACAC\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.c6f925c486aa355d1886",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC2E0\uBA85 \uD0DC\uBA85\uC870",
      "targetFaceOrPolicy": "HY\uC2E0\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.3ae451e49fbe5c79bf9c",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC2E0\uBA85 \uACAC\uACE0\uB515",
      "targetFaceOrPolicy": "HY\uACAC\uACE0\uB515",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.8c04e7e2ea1025f6ca05",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC2E0\uBA85 \uACAC\uBA85\uC870",
      "targetFaceOrPolicy": "HY\uACAC\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.23e7c5a7664920a458ed",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC2E0\uBA85 \uD0DC\uADF8\uB798\uD53D",
      "targetFaceOrPolicy": "HY\uADF8\uB798\uD53D",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.5ac4e056107231f6e274",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC2E0\uBA85 \uC911\uACE0\uB515",
      "targetFaceOrPolicy": "HY\uC911\uACE0\uB515",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.8af20db49db593ed9c91",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD0DC \uAC00\uB294 \uD5E4\uB4DC\uB77C\uC778T",
      "targetFaceOrPolicy": "HY\uD5E4\uB4DC\uB77C\uC778M",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.0e6a017c6548f0a4478e",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC591\uC7AC \uD2BC\uD2BCB",
      "targetFaceOrPolicy": "\uC591\uC7AC\uD2BC\uD2BC\uCCB4B",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.e945bd4304ec35757034",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD0DC \uAC00\uB294 \uD5E4\uB4DC\uB77C\uC778D",
      "targetFaceOrPolicy": "HY\uD5E4\uB4DC\uB77C\uC778M",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.60f52a8e1aa4cf15bace",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uC591\uACAC\uACE0\uB515",
      "targetFaceOrPolicy": "HY\uACAC\uACE0\uB515",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.bb4f6d3cbc27e4842ced",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "Gulim",
      "targetFaceOrPolicy": "\uAD74\uB9BC",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.5e0fe830f4233fa0036b",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "HYHeadLine Medium",
      "targetFaceOrPolicy": "HY\uD5E4\uB4DC\uB77C\uC778M",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.322517a7b5b2cf9f9354",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "Malgun Gothic",
      "targetFaceOrPolicy": "\uB9D1\uC740 \uACE0\uB515",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.2a1dffea82c4d40a16ea",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uCEF4\uBC14\uD0D5",
      "targetFaceOrPolicy": "\uD568\uCD08\uB86C\uBC14\uD0D5",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.97ebc33a60ff30158048",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uCEF4\uB3CB\uC6C0",
      "targetFaceOrPolicy": "\uD568\uCD08\uB86C\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.bb3f0e14de2ebb01bd16",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC0C8\uBC14\uD0D5",
      "targetFaceOrPolicy": "\uD55C\uCEF4\uBC14\uD0D5",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.e0d0b32f459e04124e87",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC0C8\uB3CB\uC6C0",
      "targetFaceOrPolicy": "\uD55C\uCEF4\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.4eb19e7e8b7605e4132c",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uBC14\uD0D5",
      "targetFaceOrPolicy": "\uC0C8\uBC14\uD0D5",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.1b817ec5d7197c6f769d",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uB3CB\uC6C0",
      "targetFaceOrPolicy": "\uC0C8\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.82858c7547853b3a83de",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC0C8\uAD74\uB9BC",
      "targetFaceOrPolicy": "\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.4938577f57a49c4e268d",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uAD74\uB9BC",
      "targetFaceOrPolicy": "\uC0C8\uAD74\uB9BC",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.ea987371d871a00af454",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC0C8\uAD81\uC11C",
      "targetFaceOrPolicy": "\uBC14\uD0D5",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.97cf5fc0b55001532a17",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uAD81\uC11C",
      "targetFaceOrPolicy": "\uC0C8\uAD81\uC11C",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.2676e8856a3e992fc55c",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uBC31\uBB35 \uAD74\uB9BC",
      "targetFaceOrPolicy": "\uAD74\uB9BC",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.5060ec129a132f6b0ed8",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uBC31\uBB35 \uB3CB\uC6C0",
      "targetFaceOrPolicy": "\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.1f0db75178da866930cf",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uBC31\uBB35 \uBC14\uD0D5",
      "targetFaceOrPolicy": "\uBC14\uD0D5",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.d355708a45c4aa899a79",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uBC31\uBB35 \uD5E4\uB4DC\uB77C\uC778",
      "targetFaceOrPolicy": "\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.ab769c76e0840dd9eacd",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uAC00\uB294\uC548\uC0C1\uC218\uCCB4",
      "targetFaceOrPolicy": "\uD568\uCD08\uB86C\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.cc56b771cb3b1239eba1",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC911\uAC04\uC548\uC0C1\uC218\uCCB4",
      "targetFaceOrPolicy": "\uD568\uCD08\uB86C\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.0f86cc67128c6997da44",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uAD75\uC740\uC548\uC0C1\uC218\uCCB4",
      "targetFaceOrPolicy": "\uD568\uCD08\uB86C\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.b879e9b425a7793ea774",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "HY\uADF8\uB798\uD53DM",
      "targetFaceOrPolicy": "HY\uADF8\uB798\uD53D",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.40fbc1e6f30101ae68fa",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uBA85\uC870",
      "targetFaceOrPolicy": "\uBC14\uD0D5",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": 1,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.4c85792a6a19c15c8ed9",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uACE0\uB515",
      "targetFaceOrPolicy": "\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.7c63499818a8127da136",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC0D8\uBB3C",
      "targetFaceOrPolicy": "\uACE0\uB515",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.cc90186faae0ade11816",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD544\uAE30",
      "targetFaceOrPolicy": "\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.acd2d8bf13447bce8562",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC2DC\uC2A4\uD15C",
      "targetFaceOrPolicy": "\uACE0\uB515",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.f6c09d93fda9338ee455",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "HY\uB465\uADFC\uACE0\uB515",
      "targetFaceOrPolicy": "\uC2DC\uC2A4\uD15C",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.6a218fa2021ea8480d5b",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC61B\uD55C\uAE00",
      "targetFaceOrPolicy": "\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.7a1bc7bf02176eb7f93c",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uAC00\uB294\uACF5\uD55C",
      "targetFaceOrPolicy": "\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.076d6d26c73591e738da",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC911\uAC04\uACF5\uD55C",
      "targetFaceOrPolicy": "\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.97a58871e8b77123ffdd",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uAD75\uC740\uACF5\uD55C",
      "targetFaceOrPolicy": "\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.6e82333bae5db5a0b5b6",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uAC00\uB294\uD55C",
      "targetFaceOrPolicy": "\uC0D8\uBB3C",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.b7743959065c033acee2",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC911\uAC04\uD55C",
      "targetFaceOrPolicy": "\uC0D8\uBB3C",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.80a885d73f79a0335332",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uAD75\uC740\uD55C",
      "targetFaceOrPolicy": "\uC0D8\uBB3C",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.683b09b25352d5907e2e",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD734\uBA3C\uBA85\uC870",
      "targetFaceOrPolicy": "\uC61B\uD55C\uAE00",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.747672692233145fb8da",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD734\uBA3C\uACE0\uB515",
      "targetFaceOrPolicy": "\uACE0\uB515",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.b9b24d1cd43d28b8abdf",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uAC00\uB294\uC548\uC0C1\uC218\uCCB4",
      "targetFaceOrPolicy": "\uAC00\uB294\uD55C",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.40a6b63b180c10dae20c",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC911\uAC04\uC548\uC0C1\uC218\uCCB4",
      "targetFaceOrPolicy": "\uC911\uAC04\uD55C",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.8a4e186a23992f2fd7bc",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uAD75\uC740\uC548\uC0C1\uC218\uCCB4",
      "targetFaceOrPolicy": "\uAD75\uC740\uD55C",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.4523ef8f0c82821dc75d",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD734\uBA3C\uAC00\uB294\uC0D8\uCCB4",
      "targetFaceOrPolicy": "\uAC00\uB294\uD55C",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.5c34c1eb8394b207d5b6",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD734\uBA3C\uC911\uAC04\uC0D8\uCCB4",
      "targetFaceOrPolicy": "\uC911\uAC04\uD55C",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.d50b8431553d792c54b3",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD734\uBA3C\uAD75\uC740\uC0D8\uCCB4",
      "targetFaceOrPolicy": "\uAD75\uC740\uD55C",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.cf34065ce59f174c73ed",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD734\uBA3C\uAC00\uB294\uD338\uCCB4",
      "targetFaceOrPolicy": "\uD734\uBA3C\uAC00\uB294\uC0D8\uCCB4",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.1ad182efbd743de14cd0",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD734\uBA3C\uC911\uAC04\uD338\uCCB4",
      "targetFaceOrPolicy": "\uD734\uBA3C\uC911\uAC04\uC0D8\uCCB4",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.ef8728d78779d79df266",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD734\uBA3C\uAD75\uC740\uD338\uCCB4",
      "targetFaceOrPolicy": "\uD734\uBA3C\uAD75\uC740\uC0D8\uCCB4",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.36eb24ad1699bacfb013",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD734\uBA3C\uC61B\uCCB4",
      "targetFaceOrPolicy": "\uD734\uBA3C\uACE0\uB515",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.45f8ba3b8b94be11a9f9",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uC591\uC2E0\uBA85\uC870",
      "targetFaceOrPolicy": "\uD734\uBA3C\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.066347cb43acd6d2ebb4",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uC591\uACAC\uBA85\uC870",
      "targetFaceOrPolicy": "\uD734\uBA3C\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.70f8ba4597b8a08ac36a",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uC591\uC911\uACE0\uB515",
      "targetFaceOrPolicy": "\uD734\uBA3C\uACE0\uB515",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.b7e3dd13b103a05065d0",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uC591\uACAC\uACE0\uB515",
      "targetFaceOrPolicy": "\uD734\uBA3C\uACE0\uB515",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.c45afce08e33aa8ccf69",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uC591\uADF8\uB798\uD53D",
      "targetFaceOrPolicy": "\uAD74\uB9BC",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.c4f69285c803b9a08307",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uC591\uAD81\uC11C",
      "targetFaceOrPolicy": "\uAD81\uC11C",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.8f0efa840c322ae3b797",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uBB38\uD654\uBC14\uD0D5",
      "targetFaceOrPolicy": "\uD734\uBA3C\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.6dd229ef7f2d80c1c16f",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uBB38\uD654\uBC14\uD0D5\uC81C\uBAA9",
      "targetFaceOrPolicy": "\uD734\uBA3C\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.23e73e045c671b912a5d",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uBB38\uD654\uB3CB\uC6C0",
      "targetFaceOrPolicy": "\uD734\uBA3C\uACE0\uB515",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.e3312b62a241444b3467",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uBB38\uD654\uB3CB\uC6C0\uC81C\uBAA9",
      "targetFaceOrPolicy": "\uD734\uBA3C\uACE0\uB515",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.c5ccb3e16e24d7231b30",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uBB38\uD654\uC4F0\uAE30",
      "targetFaceOrPolicy": "\uD734\uBA3C\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.3538cfe43cf096282c35",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uBB38\uD654\uC4F0\uAE30\uD758\uB9BC",
      "targetFaceOrPolicy": "\uD734\uBA3C\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.ef94a585ea6e7c9cc646",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD39C\uD758\uB9BC",
      "targetFaceOrPolicy": "\uD734\uBA3C\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.f2b23ddae28567b37660",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uBCF5\uC22D\uC544",
      "targetFaceOrPolicy": "\uD734\uBA3C\uC911\uAC04\uD338\uCCB4",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.0dd7a7f70902cc9ab64f",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC625\uC218\uC218",
      "targetFaceOrPolicy": "\uD734\uBA3C\uC61B\uCCB4",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.772dd3ccadb4cbc6e817",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC624\uC774",
      "targetFaceOrPolicy": "\uD544\uAE30",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.244fcfb638cbf0173b6e",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uAC00\uC9C0",
      "targetFaceOrPolicy": "\uD544\uAE30",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.d6a2fa86d67621026f2b",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uAC15\uB0AD\uCF69",
      "targetFaceOrPolicy": "\uD55C\uC591\uADF8\uB798\uD53D",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.5bc36154817756fa512f",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uB538\uAE30",
      "targetFaceOrPolicy": "\uD734\uBA3C\uC61B\uCCB4",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.1df310a87d82d7961d8e",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD0C0\uC774\uD504",
      "targetFaceOrPolicy": "\uAD75\uC740\uACF5\uD55C",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.1f479840b7ba339b677a",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD0DC \uB098\uBB34",
      "targetFaceOrPolicy": "\uD734\uBA3C\uACE0\uB515",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.4ee0c6259f428a3cd2b8",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD0DC \uD5E4\uB4DC\uB77C\uC778D",
      "targetFaceOrPolicy": "\uC2E0\uBA85 \uACAC\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.7f9b02f0964f7a332c69",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD0DC \uAC00\uB294 \uD5E4\uB4DC\uB77C\uC778D",
      "targetFaceOrPolicy": "\uD0DC \uD5E4\uB4DC\uB77C\uC778D",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.559fbf673ad7c7319183",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD0DC \uD5E4\uB4DC\uB77C\uC778T",
      "targetFaceOrPolicy": "\uC2E0\uBA85 \uACAC\uACE0\uB515",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.cf964e285149be7f92e2",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD0DC \uAC00\uB294 \uD5E4\uB4DC\uB77C\uC778T",
      "targetFaceOrPolicy": "\uD0DC \uD5E4\uB4DC\uB77C\uC778T",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.8ab2405ad0e5e2b9a152",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC591\uC7AC \uB2E4\uC6B4\uBA85\uC870M",
      "targetFaceOrPolicy": "\uD734\uBA3C\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.75d2241f5fe94b4b91ba",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC591\uC7AC \uBCF8\uBAA9\uAC01M",
      "targetFaceOrPolicy": "\uC625\uC218\uC218",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.2190b89fd0bb4388018c",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC591\uC7AC \uC18C\uC2AC",
      "targetFaceOrPolicy": "\uD0DC \uB098\uBB34",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.73b3d3a997642f65fb7c",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC591\uC7AC \uD2BC\uD2BCB",
      "targetFaceOrPolicy": "\uD0DC \uAC00\uB294 \uD5E4\uB4DC\uB77C\uC778T",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.a25323bbe3c467c0eda8",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC591\uC7AC \uCC38\uC22FB",
      "targetFaceOrPolicy": "\uD55C\uC591\uACAC\uACE0\uB515",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.04b04c86a8ef4e511cac",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC591\uC7AC \uB458\uAE30",
      "targetFaceOrPolicy": "\uAC00\uC9C0",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.71b14a9add21a371bc5c",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC591\uC7AC \uB9E4\uD654",
      "targetFaceOrPolicy": "\uC625\uC218\uC218",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.58311349e714549cc59e",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC591\uC7AC \uC0E4\uB12C",
      "targetFaceOrPolicy": "\uD0DC \uB098\uBB34",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.c3014ca530ec6b626eea",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC591\uC7AC \uC640\uB2F9",
      "targetFaceOrPolicy": "\uC591\uC7AC \uCC38\uC22FB",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.bfe84a1062f3cac87ddf",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC591\uC7AC \uC774\uB2C8\uC15C",
      "targetFaceOrPolicy": "\uC591\uC7AC \uCC38\uC22FB",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.beaeb1d0d74902999b4f",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC2E0\uBA85 \uC138\uBA85\uC870",
      "targetFaceOrPolicy": "\uD734\uBA3C\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.bfdac82a518bf3600f37",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC2E0\uBA85 \uC2E0\uBA85\uC870",
      "targetFaceOrPolicy": "\uD734\uBA3C\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.2a0401de3dd1a28fb8ef",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC2E0\uBA85 \uC2E0\uC2E0\uBA85\uC870",
      "targetFaceOrPolicy": "\uD734\uBA3C\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.92ba6d5679993bf50217",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC2E0\uBA85 \uC911\uBA85\uC870",
      "targetFaceOrPolicy": "\uD734\uBA3C\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.9f73bf613d178aad5c7a",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC2E0\uBA85 \uD0DC\uBA85\uC870",
      "targetFaceOrPolicy": "\uD734\uBA3C\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.10f50343f3549c68730b",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC2E0\uBA85 \uACAC\uBA85\uC870",
      "targetFaceOrPolicy": "\uD734\uBA3C\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.daad32224ff650aa7edb",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC2E0\uBA85 \uC2E0\uBB38\uBA85\uC870",
      "targetFaceOrPolicy": "\uD734\uBA3C\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.22a51d84831126a5f7f8",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC2E0\uBA85 \uC21C\uBA85\uC870",
      "targetFaceOrPolicy": "\uD734\uBA3C\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.e9849013ddb4daaf4e4a",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC2E0\uBA85 \uC138\uACE0\uB515",
      "targetFaceOrPolicy": "\uD734\uBA3C\uACE0\uB515",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.2d986fb71bb15758220f",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC2E0\uBA85 \uC911\uACE0\uB515",
      "targetFaceOrPolicy": "\uD734\uBA3C\uACE0\uB515",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.1ac04a3d513de6a4b4f2",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC2E0\uBA85 \uD0DC\uACE0\uB515",
      "targetFaceOrPolicy": "\uD734\uBA3C\uACE0\uB515",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.5cef4b1d0b53eb31f64b",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC2E0\uBA85 \uACAC\uACE0\uB515",
      "targetFaceOrPolicy": "\uD734\uBA3C\uACE0\uB515",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.fbf4a469ba33e412d3f8",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC2E0\uBA85 \uC138\uB098\uB8E8",
      "targetFaceOrPolicy": "\uD734\uBA3C\uACE0\uB515",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.6acd48ec96c99316a019",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC2E0\uBA85 \uB514\uB098\uB8E8",
      "targetFaceOrPolicy": "\uD734\uBA3C\uACE0\uB515",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.b1ddf59ab8d954039176",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC2E0\uBA85 \uC2E0\uADF8\uB798\uD53D",
      "targetFaceOrPolicy": "\uD55C\uC591\uADF8\uB798\uD53D",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.0d217a1553cdc1c40207",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC2E0\uBA85 \uD0DC\uADF8\uB798\uD53D",
      "targetFaceOrPolicy": "\uD55C\uC591\uADF8\uB798\uD53D",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.7928ea6904004f2f8516",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC2E0\uBA85 \uAD81\uC11C",
      "targetFaceOrPolicy": "\uD55C\uC591\uAD81\uC11C",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.122c325267a7885bee9f",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "SPOQAHANSANS",
      "targetFaceOrPolicy": "SpoqaHanSans",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "0",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.33ae9124672740f36193",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uC591\uC911\uACE0\uB515",
      "targetFaceOrPolicy": "HY\uC911\uACE0\uB515",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.e6e2545e37da3ffa8b56",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uC591\uC2E0\uBA85\uC870",
      "targetFaceOrPolicy": "HY\uC2E0\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.76ef5e341bd095003118",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uBA85\uC870",
      "targetFaceOrPolicy": "HY\uACAC\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": 0,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.31fa5e0208d57d1fdbcc",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "HCI Poppy",
      "targetFaceOrPolicy": "Palatino Linotype",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.81daf7bd554e1507c2ed",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC2E0\uBA85 \uD0DC\uACE0\uB515",
      "targetFaceOrPolicy": "HY\uC911\uACE0\uB515",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.07fd6e1a3394e03260fd",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC0B0\uC138\uB9AC\uD504",
      "targetFaceOrPolicy": "Calibri",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.0a4d3adcb3da3b664183",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uC591\uACAC\uBA85\uC870",
      "targetFaceOrPolicy": "HY\uACAC\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.66d36fa46504fd19b7e2",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC2E0\uBA85 \uD0DC\uBA85\uC870",
      "targetFaceOrPolicy": "HY\uC2E0\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.c6a4690fe0fcb0d831c0",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC2E0\uBA85 \uACAC\uACE0\uB515",
      "targetFaceOrPolicy": "HY\uACAC\uACE0\uB515",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.075ece08e48f4e96278a",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC2E0\uBA85 \uACAC\uBA85\uC870",
      "targetFaceOrPolicy": "HY\uACAC\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.44910d6407e72dfbbeb6",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC2E0\uBA85 \uD0DC\uADF8\uB798\uD53D",
      "targetFaceOrPolicy": "HY\uADF8\uB798\uD53D",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.5fe82b0b6e6883112d1f",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC2E0\uBA85 \uC911\uACE0\uB515",
      "targetFaceOrPolicy": "HY\uC911\uACE0\uB515",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.700772b281cef9cdbc60",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC591\uC7AC \uD2BC\uD2BCB",
      "targetFaceOrPolicy": "\uC591\uC7AC\uD2BC\uD2BC\uCCB4B",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.623eb3aa318ed9f440a5",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uC591\uACAC\uACE0\uB515",
      "targetFaceOrPolicy": "HY\uACAC\uACE0\uB515",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.1926932fb6d61ec82838",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "Gulim",
      "targetFaceOrPolicy": "\uAD74\uB9BC",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.eb8755aba4e60ddddea0",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "HYHeadLine Medium",
      "targetFaceOrPolicy": "HY\uD5E4\uB4DC\uB77C\uC778M",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.4ecd5e57c0728fa82986",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "Malgun Gothic",
      "targetFaceOrPolicy": "\uB9D1\uC740 \uACE0\uB515",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.e0e8549efba0930c80b9",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "Tahoma",
      "targetFaceOrPolicy": "\uD568\uCD08\uB86C\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.02eb7a1598c678ddc438",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "MS Sans Serif",
      "targetFaceOrPolicy": "\uD568\uCD08\uB86C\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.28d7eeb9953ec6f80b1b",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "Times New Roman",
      "targetFaceOrPolicy": "\uD568\uCD08\uB86C\uBC14\uD0D5",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.b90ab7a4f4de860e7278",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uCEF4\uBC14\uD0D5",
      "targetFaceOrPolicy": "\uD568\uCD08\uB86C\uBC14\uD0D5",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.cf3d0ecf5dff293f66c5",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uCEF4\uB3CB\uC6C0",
      "targetFaceOrPolicy": "\uD568\uCD08\uB86C\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.baef5d40d31beb701812",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC0C8\uBC14\uD0D5",
      "targetFaceOrPolicy": "\uD55C\uCEF4\uBC14\uD0D5",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.60f0549bf5064b726a92",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC0C8\uB3CB\uC6C0",
      "targetFaceOrPolicy": "\uD55C\uCEF4\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.65cd44d67257bcf741cc",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uBC14\uD0D5",
      "targetFaceOrPolicy": "\uC0C8\uBC14\uD0D5",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.b7661d041013edcd4682",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uB3CB\uC6C0",
      "targetFaceOrPolicy": "\uC0C8\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.423952186940188fb8fb",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC0C8\uAD74\uB9BC",
      "targetFaceOrPolicy": "\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.cf202a8851c59dbc6bf2",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uAD74\uB9BC",
      "targetFaceOrPolicy": "\uC0C8\uAD74\uB9BC",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.7639fe6289a03755c057",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC0C8\uAD81\uC11C",
      "targetFaceOrPolicy": "\uBC14\uD0D5",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.37e21fb9d45988d9cb72",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uAD81\uC11C",
      "targetFaceOrPolicy": "\uC0C8\uAD81\uC11C",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.733e70a99ead7df033c6",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uBC31\uBB35 \uAD74\uB9BC",
      "targetFaceOrPolicy": "\uAD74\uB9BC",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.8ff9ea9bc81862cfc7ef",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uBC31\uBB35 \uB3CB\uC6C0",
      "targetFaceOrPolicy": "\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.81baa9cb2de7284c2046",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uBC31\uBB35 \uBC14\uD0D5",
      "targetFaceOrPolicy": "\uBC14\uD0D5",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.2a71cd3cbcc17415d55c",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uBC31\uBB35 \uD5E4\uB4DC\uB77C\uC778",
      "targetFaceOrPolicy": "\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.b51dde1307674029c331",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "HY\uADF8\uB798\uD53DM",
      "targetFaceOrPolicy": "HY\uADF8\uB798\uD53D",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.f84b5125419b5ff0770c",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uBA85\uC870",
      "targetFaceOrPolicy": "\uBC14\uD0D5",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": 1,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.850fe545764a4f76d983",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uACE0\uB515",
      "targetFaceOrPolicy": "\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.aa00d1bf9e2d543898e8",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC0B0\uC138\uB9AC\uD504",
      "targetFaceOrPolicy": "\uACE0\uB515",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.b498ab67acd69f1ec90e",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD544\uAE30",
      "targetFaceOrPolicy": "\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.9e746e7c49f738148aa9",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uC591\uC2E0\uBA85\uC870",
      "targetFaceOrPolicy": "\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.204a772ac9846dd3252b",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uC591\uC911\uACE0\uB515",
      "targetFaceOrPolicy": "\uACE0\uB515",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.2e8e4aeeeff1d576aae0",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC2DC\uC2A4\uD15C",
      "targetFaceOrPolicy": "\uD55C\uC591\uC911\uACE0\uB515",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.f409d3571b30627cf6a5",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "HY\uB465\uADFC\uACE0\uB515",
      "targetFaceOrPolicy": "\uC2DC\uC2A4\uD15C",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.5b6be80177ef39b3927c",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uC591\uACAC\uBA85\uC870",
      "targetFaceOrPolicy": "\uD55C\uC591\uC2E0\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.4ec11f9a74196684b801",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uC591\uACAC\uACE0\uB515",
      "targetFaceOrPolicy": "\uD55C\uC591\uC911\uACE0\uB515",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.66c7676496b6c52532a2",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uC591\uADF8\uB798\uD53D",
      "targetFaceOrPolicy": "\uAD74\uB9BC",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.5ede4957a3bcd9c15810",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uC591\uAD81\uC11C",
      "targetFaceOrPolicy": "\uAD81\uC11C",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.ce0eaaacfd32ef8b7b91",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "SPOQAHANSANS",
      "targetFaceOrPolicy": "SpoqaHanSans",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "1",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.532c5fd9b02fe8924747",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uC591\uC911\uACE0\uB515",
      "targetFaceOrPolicy": "HY\uC911\uACE0\uB515",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "2",
        "profile": "canvas2d"
      },
      "order": 0,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.37afa9b1a111600d133e",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uC591\uC2E0\uBA85\uC870",
      "targetFaceOrPolicy": "HY\uC2E0\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "2",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.ac22b4bf32c14432b69e",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uBA85\uC870",
      "targetFaceOrPolicy": "HY\uACAC\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "2",
        "profile": "canvas2d"
      },
      "order": 0,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.3115a23acd283ed74c73",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC2E0\uBA85 \uD0DC\uACE0\uB515",
      "targetFaceOrPolicy": "HY\uC911\uACE0\uB515",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "2",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.2cdb104fa6d323421f4c",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "Gulim",
      "targetFaceOrPolicy": "\uAD74\uB9BC",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "2",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.e6c5aefd48e8676a6d50",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "Malgun Gothic",
      "targetFaceOrPolicy": "\uB9D1\uC740 \uACE0\uB515",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "2",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.27692fc418e5d0a0aade",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uCEF4\uBC14\uD0D5",
      "targetFaceOrPolicy": "\uD568\uCD08\uB86C\uBC14\uD0D5",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "2",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.0781dd11aef20695a084",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uCEF4\uB3CB\uC6C0",
      "targetFaceOrPolicy": "\uD568\uCD08\uB86C\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "2",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.e23ac5016e8c9b45fd42",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC0C8\uBC14\uD0D5",
      "targetFaceOrPolicy": "\uD55C\uCEF4\uBC14\uD0D5",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "2",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.f50fa6c4c0ce6ee331ff",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC0C8\uB3CB\uC6C0",
      "targetFaceOrPolicy": "\uD55C\uCEF4\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "2",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.a410cf33a92fd7b6683f",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uBC14\uD0D5",
      "targetFaceOrPolicy": "\uC0C8\uBC14\uD0D5",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "2",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.8148573c6249f4090951",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uB3CB\uC6C0",
      "targetFaceOrPolicy": "\uC0C8\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "2",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.39cb1ca358ad6438c4cb",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC0C8\uAD74\uB9BC",
      "targetFaceOrPolicy": "\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "2",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.5865a6d8dd85c317b6f8",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uAD74\uB9BC",
      "targetFaceOrPolicy": "\uC0C8\uAD74\uB9BC",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "2",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.ead41651158facfd5259",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC0C8\uAD81\uC11C",
      "targetFaceOrPolicy": "\uBC14\uD0D5",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "2",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.87fabbf31a2afbd9f4bb",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uAD81\uC11C",
      "targetFaceOrPolicy": "\uC0C8\uAD81\uC11C",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "2",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.88b9d28bc283ca1f0b13",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uBA85\uC870",
      "targetFaceOrPolicy": "\uBC14\uD0D5",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "2",
        "profile": "canvas2d"
      },
      "order": 1,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.d49f28ed798c69f9398b",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uC591\uC2E0\uBA85\uC870",
      "targetFaceOrPolicy": "\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "2",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.b42eaa2121a51288ae69",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uC591\uC911\uACE0\uB515",
      "targetFaceOrPolicy": "\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "2",
        "profile": "canvas2d"
      },
      "order": 1,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.e2884c2caefee1f356e8",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "SPOQAHANSANS",
      "targetFaceOrPolicy": "SpoqaHanSans",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "2",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.a2523b85a56405a7ff7d",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uC591\uC911\uACE0\uB515",
      "targetFaceOrPolicy": "HY\uC911\uACE0\uB515",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "3",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.28fe4f55ca0cb6c2e241",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uC591\uC2E0\uBA85\uC870",
      "targetFaceOrPolicy": "HY\uC2E0\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "3",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.0d8f8381f24a58698505",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uBA85\uC870",
      "targetFaceOrPolicy": "HY\uACAC\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "3",
        "profile": "canvas2d"
      },
      "order": 0,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.8f09161e2205b8028fa3",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC2E0\uBA85 \uD0DC\uACE0\uB515",
      "targetFaceOrPolicy": "HY\uC911\uACE0\uB515",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "3",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.138c58a39b6e7e8cf567",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "Gulim",
      "targetFaceOrPolicy": "\uAD74\uB9BC",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "3",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.73f35c22925db6b15430",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "Malgun Gothic",
      "targetFaceOrPolicy": "\uB9D1\uC740 \uACE0\uB515",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "3",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.48974c2274331c44e917",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uCEF4\uBC14\uD0D5",
      "targetFaceOrPolicy": "\uD568\uCD08\uB86C\uBC14\uD0D5",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "3",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.16670d4452d0ac4ffdc9",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uCEF4\uB3CB\uC6C0",
      "targetFaceOrPolicy": "\uD568\uCD08\uB86C\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "3",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.9b6323bd207090bc86a6",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC0C8\uBC14\uD0D5",
      "targetFaceOrPolicy": "\uD55C\uCEF4\uBC14\uD0D5",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "3",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.0ed788b88848b42cbc9b",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC0C8\uB3CB\uC6C0",
      "targetFaceOrPolicy": "\uD55C\uCEF4\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "3",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.3bc7e793616a6a94b47b",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uBC14\uD0D5",
      "targetFaceOrPolicy": "\uC0C8\uBC14\uD0D5",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "3",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.ff8fcd32e18464e7eb4c",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uB3CB\uC6C0",
      "targetFaceOrPolicy": "\uC0C8\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "3",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.b348293a780f32314ffd",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC0C8\uAD74\uB9BC",
      "targetFaceOrPolicy": "\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "3",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.52efaf37fe76450e9ed5",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uAD74\uB9BC",
      "targetFaceOrPolicy": "\uC0C8\uAD74\uB9BC",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "3",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.22c20d4684759dd9e26d",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC0C8\uAD81\uC11C",
      "targetFaceOrPolicy": "\uBC14\uD0D5",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "3",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.1e454749617ccdac252d",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uAD81\uC11C",
      "targetFaceOrPolicy": "\uC0C8\uAD81\uC11C",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "3",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.e30786006c9aa1487693",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uBA85\uC870",
      "targetFaceOrPolicy": "\uBC14\uD0D5",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "3",
        "profile": "canvas2d"
      },
      "order": 1,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.b6c96997170b4e1161ea",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uACE0\uB515",
      "targetFaceOrPolicy": "\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "3",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.13a7619771a335bb889b",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uC591\uC2E0\uBA85\uC870",
      "targetFaceOrPolicy": "\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "3",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.74ff288d22161d060ad7",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uC591\uC911\uACE0\uB515",
      "targetFaceOrPolicy": "\uACE0\uB515",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "3",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.b03c8500696689530d64",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC2DC\uC2A4\uD15C",
      "targetFaceOrPolicy": "\uAD74\uB9BC",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "3",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.f437ad76ab99f1b2dec0",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "SPOQAHANSANS",
      "targetFaceOrPolicy": "SpoqaHanSans",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "3",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.140c081e9249967c4f4b",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uC591\uC2E0\uBA85\uC870",
      "targetFaceOrPolicy": "HY\uC2E0\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "4",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.fe05686d29336e3a905f",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uBA85\uC870",
      "targetFaceOrPolicy": "HY\uACAC\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "4",
        "profile": "canvas2d"
      },
      "order": 0,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.541d604dafe2216589a5",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "Gulim",
      "targetFaceOrPolicy": "\uAD74\uB9BC",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "4",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.ec29f8ae09feee7982c1",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "Malgun Gothic",
      "targetFaceOrPolicy": "\uB9D1\uC740 \uACE0\uB515",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "4",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.c1576f72df36e6741a30",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uCEF4\uBC14\uD0D5",
      "targetFaceOrPolicy": "\uD568\uCD08\uB86C\uBC14\uD0D5",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "4",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.9db78e9d9e785fce9bf0",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uCEF4\uB3CB\uC6C0",
      "targetFaceOrPolicy": "\uD568\uCD08\uB86C\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "4",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.4d56491720dbef1b864a",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC0C8\uBC14\uD0D5",
      "targetFaceOrPolicy": "\uD55C\uCEF4\uBC14\uD0D5",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "4",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.6853e19b7b0bbcfbc24a",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC0C8\uB3CB\uC6C0",
      "targetFaceOrPolicy": "\uD55C\uCEF4\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "4",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.e193c6f517eb6c7345de",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uBC14\uD0D5",
      "targetFaceOrPolicy": "\uC0C8\uBC14\uD0D5",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "4",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.bea82478aaa9418593cc",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uB3CB\uC6C0",
      "targetFaceOrPolicy": "\uC0C8\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "4",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.99bbe8902c43af0a08fb",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC0C8\uAD74\uB9BC",
      "targetFaceOrPolicy": "\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "4",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.ccf56b4520f710b47f85",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uAD74\uB9BC",
      "targetFaceOrPolicy": "\uC0C8\uAD74\uB9BC",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "4",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.db90444f9c52ed76d652",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC0C8\uAD81\uC11C",
      "targetFaceOrPolicy": "\uBC14\uD0D5",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "4",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.c353578b1be54d73d283",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uAD81\uC11C",
      "targetFaceOrPolicy": "\uC0C8\uAD81\uC11C",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "4",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.adb16ec54c4b31eebf5b",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uBA85\uC870",
      "targetFaceOrPolicy": "\uBC14\uD0D5",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "4",
        "profile": "canvas2d"
      },
      "order": 1,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.258e7f7b23ce32aabc95",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uC591\uC2E0\uBA85\uC870",
      "targetFaceOrPolicy": "\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "4",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.142d17cfc91d2866e474",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "SPOQAHANSANS",
      "targetFaceOrPolicy": "SpoqaHanSans",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "4",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.93e859e5497d4152b924",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uC591\uC911\uACE0\uB515",
      "targetFaceOrPolicy": "HY\uC911\uACE0\uB515",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "5",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.65a63417da4a297a4406",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uC591\uC2E0\uBA85\uC870",
      "targetFaceOrPolicy": "HY\uC2E0\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "5",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.bf74d065a0ea8b2220c8",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uBA85\uC870",
      "targetFaceOrPolicy": "HY\uACAC\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "5",
        "profile": "canvas2d"
      },
      "order": 0,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.ac6fbcf19e1ef5b80c1f",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC2E0\uBA85 \uACAC\uACE0\uB515",
      "targetFaceOrPolicy": "HY\uACAC\uACE0\uB515",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "5",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.a11eaee0ca2a998ac1a7",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC2E0\uBA85 \uACAC\uBA85\uC870",
      "targetFaceOrPolicy": "HY\uACAC\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "5",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.70e948d0cdd7b6111727",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC2E0\uBA85 \uD0DC\uADF8\uB798\uD53D",
      "targetFaceOrPolicy": "HY\uADF8\uB798\uD53D",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "5",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.b825e8cb4c2d6e21bdd0",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "Gulim",
      "targetFaceOrPolicy": "\uAD74\uB9BC",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "5",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.5e35c4e0a51e00e8cd35",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "HYHeadLine Medium",
      "targetFaceOrPolicy": "HY\uD5E4\uB4DC\uB77C\uC778M",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "5",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.7b56a40ef9529c0692cc",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "Malgun Gothic",
      "targetFaceOrPolicy": "\uB9D1\uC740 \uACE0\uB515",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "5",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.346abd4d396fc1c8b345",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uCEF4\uBC14\uD0D5",
      "targetFaceOrPolicy": "\uD568\uCD08\uB86C\uBC14\uD0D5",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "5",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.61c97b6ac43aa5e92caa",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uCEF4\uB3CB\uC6C0",
      "targetFaceOrPolicy": "\uD568\uCD08\uB86C\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "5",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.98705adaf297df20e681",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC0C8\uBC14\uD0D5",
      "targetFaceOrPolicy": "\uD55C\uCEF4\uBC14\uD0D5",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "5",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.3419e34fd43ffff48f94",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC0C8\uB3CB\uC6C0",
      "targetFaceOrPolicy": "\uD55C\uCEF4\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "5",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.f1256c3b87ef9041dac0",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uBC14\uD0D5",
      "targetFaceOrPolicy": "\uC0C8\uBC14\uD0D5",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "5",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.b8e9822435dfc84bffcf",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uB3CB\uC6C0",
      "targetFaceOrPolicy": "\uC0C8\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "5",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.3f62b538bccf4a597534",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC0C8\uAD74\uB9BC",
      "targetFaceOrPolicy": "\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "5",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.6f748ccf3460e236dcfe",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uAD74\uB9BC",
      "targetFaceOrPolicy": "\uC0C8\uAD74\uB9BC",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "5",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.acaa8a572fa394062180",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC0C8\uAD81\uC11C",
      "targetFaceOrPolicy": "\uBC14\uD0D5",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "5",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.16ec54d4dc791a620abe",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uAD81\uC11C",
      "targetFaceOrPolicy": "\uC0C8\uAD81\uC11C",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "5",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.016a680e0a20ce023e8b",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uBA85\uC870",
      "targetFaceOrPolicy": "\uBC14\uD0D5",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "5",
        "profile": "canvas2d"
      },
      "order": 1,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.348daaa7cbd93a545548",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC2DC\uC2A4\uD15C",
      "targetFaceOrPolicy": "\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "5",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.62574eb42352ba172b8b",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uC591\uC2E0\uBA85\uC870",
      "targetFaceOrPolicy": "\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "5",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.09187c7f9d882f1590e0",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uC591\uC911\uACE0\uB515",
      "targetFaceOrPolicy": "\uD55C\uC591\uC2E0\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "5",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.4aedbd212462d59d94e0",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "SPOQAHANSANS",
      "targetFaceOrPolicy": "SpoqaHanSans",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "5",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.da8d2183a27ac7a6a338",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uC591\uC2E0\uBA85\uC870",
      "targetFaceOrPolicy": "HY\uC2E0\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "6",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.f4df753633f252d75285",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uBA85\uC870",
      "targetFaceOrPolicy": "HY\uACAC\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "6",
        "profile": "canvas2d"
      },
      "order": 0,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.00fe182a569fe3a4c03d",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "Gulimche",
      "targetFaceOrPolicy": "\uAD74\uB9BC\uCCB4",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "6",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.53bb2ec848c92a6f050f",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "Gulim",
      "targetFaceOrPolicy": "\uAD74\uB9BC",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "6",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.5b6f7a31aca9a9807ce4",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "Malgun Gothic",
      "targetFaceOrPolicy": "\uB9D1\uC740 \uACE0\uB515",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "6",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.66c32b65cd1638edc363",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD568\uCD08\uB86C\uB3CB\uC6C0",
      "targetFaceOrPolicy": "\uD568\uCD08\uB86C\uBC14\uD0D5",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "6",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.ae81276d46c81b7450cd",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uCEF4\uBC14\uD0D5",
      "targetFaceOrPolicy": "\uD568\uCD08\uB86C\uBC14\uD0D5",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "6",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.9cc24c2435946230ed2b",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uCEF4\uB3CB\uC6C0",
      "targetFaceOrPolicy": "\uD568\uCD08\uB86C\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "6",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.8fc376b2252f4c869b62",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC0C8\uBC14\uD0D5",
      "targetFaceOrPolicy": "\uD55C\uCEF4\uBC14\uD0D5",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "6",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.5fe8473c404dd197cf58",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC0C8\uB3CB\uC6C0",
      "targetFaceOrPolicy": "\uD55C\uCEF4\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "6",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.ca17e3b44572c1e4b587",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uBC14\uD0D5",
      "targetFaceOrPolicy": "\uC0C8\uBC14\uD0D5",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "6",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.aba22751e79bf07e98e2",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uB3CB\uC6C0",
      "targetFaceOrPolicy": "\uC0C8\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "6",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.7733a8cba2fc5dd33b06",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC0C8\uAD74\uB9BC",
      "targetFaceOrPolicy": "\uB3CB\uC6C0",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "6",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.abee1b6088d71050d97d",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uAD74\uB9BC",
      "targetFaceOrPolicy": "\uC0C8\uAD74\uB9BC",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "6",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.c85113339920176c6b0d",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uC0C8\uAD81\uC11C",
      "targetFaceOrPolicy": "\uBC14\uD0D5",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "6",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.d48375826cc4cd91980b",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uAD81\uC11C",
      "targetFaceOrPolicy": "\uC0C8\uAD81\uC11C",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "6",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.a1b8c69d500b30153870",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uBA85\uC870",
      "targetFaceOrPolicy": "\uBC14\uD0D5",
      "conditions": {
        "altType": "source:2->target:1",
        "languageSlot": "6",
        "profile": "canvas2d"
      },
      "order": 1,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.507dbe3341fe854768c7",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "\uD55C\uAE00 \uD480\uC5B4\uC4F0\uAE30",
      "targetFaceOrPolicy": "\uBA85\uC870",
      "conditions": {
        "altType": "source:2->target:2",
        "languageSlot": "6",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.dc809c56144aa22001ec",
      "sourceBoundaryId": "studio-substitution.substitution-tables",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": "SPOQAHANSANS",
      "targetFaceOrPolicy": "SpoqaHanSans",
      "conditions": {
        "altType": "source:1->target:1",
        "languageSlot": "6",
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.d45114ab935a0f64fb24",
      "sourceBoundaryId": "studio-substitution.display-chain",
      "relationType": "style-fallback",
      "decisionPlane": "paint",
      "sourceFace": null,
      "targetFaceOrPolicy": "confirmed exact local or registered original family",
      "conditions": {
        "profile": "canvas2d"
      },
      "order": 0,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.4b0f0e36407c7d1478cb",
      "sourceBoundaryId": "studio-substitution.display-chain",
      "relationType": "official-successor",
      "decisionPlane": "paint",
      "sourceFace": null,
      "targetFaceOrPolicy": "confirmed government successor family",
      "conditions": {
        "profile": "canvas2d"
      },
      "order": 1,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.3d36e30af2b3eafc0014",
      "sourceBoundaryId": "studio-substitution.display-chain",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": null,
      "targetFaceOrPolicy": "resolved web substitution family",
      "conditions": {
        "profile": "canvas2d"
      },
      "order": 2,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.aef174ec2cbb69d68246",
      "sourceBoundaryId": "studio-substitution.display-chain",
      "relationType": "document-substitution",
      "decisionPlane": "paint",
      "sourceFace": null,
      "targetFaceOrPolicy": "confirmed or registered document substFont family",
      "conditions": {
        "profile": "canvas2d"
      },
      "order": 3,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-substitution.8276e3c7e99757ae44c7",
      "sourceBoundaryId": "studio-substitution.display-chain",
      "relationType": "generic-fallback",
      "decisionPlane": "paint",
      "sourceFace": null,
      "targetFaceOrPolicy": "system fallback and generic terminal families",
      "conditions": {
        "profile": "canvas2d"
      },
      "order": 4,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-canvas-patch.afffc48cd5e801e57b86",
      "sourceBoundaryId": "studio-canvas-patch.css-family-substitution",
      "relationType": "paint-substitute",
      "decisionPlane": "paint",
      "sourceFace": null,
      "targetFaceOrPolicy": "replace the first quoted Canvas2D family with the display fallback chain",
      "conditions": {
        "profile": "canvas2d"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    }
  ]);

  // build.noindex/task567/stage3-2/upstream-v087/rhwp-studio/src/core/generated/font-rule-projections/webfont-supply.ts
  var FONT_RULE_CANVAS2D_WEBFONT_META = Object.freeze({
    "schemaVersion": "1.0",
    "sourceCommit": "a1f9872e28aea6755b656161ed1802f73308da58",
    "inputSha256": "6148c568b05fea9ec317759bfc7a19762f93eded557c5b5af01efbb7057ed266",
    "projectionId": "canvas2d-webfont",
    "projectionSha256": "b6ff0ce6d73634bc75b15d2ed20f70465d7a32f9c525b8030b365d7a7f464245",
    "ruleCount": 153
  });
  var FONT_RULE_CANVAS2D_WEBFONT_RULES = Object.freeze([
    {
      "ruleId": "rule.studio-supply.bd74329daa5a2a185478.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uD568\uCD08\uB86C\uB3CB\uC6C0",
      "targetFaceOrPolicy": "CDN_HAMCHOD_R",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "\uD568\uCD08\uB86C\uB3CB\uC6C0",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/gh/projectnoonnu/noonfonts_four@1.0/HCRDotum.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.05ea00b9c9e0a769922f.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uD568\uCD08\uB86C\uBC14\uD0D5",
      "targetFaceOrPolicy": "CDN_HAMCHOB_R",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "\uD568\uCD08\uB86C\uBC14\uD0D5",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/gh/projectnoonnu/noonfonts_2104@1.0/HANBatang.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.bc675f06812aac14a681.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uD568\uCD08\uB871\uB3CB\uC6C0",
      "targetFaceOrPolicy": "CDN_HAMCHOD_R",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "\uD568\uCD08\uB871\uB3CB\uC6C0",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/gh/projectnoonnu/noonfonts_four@1.0/HCRDotum.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.54d07bcc1a0df04ff7dc.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uD568\uCD08\uB871\uBC14\uD0D5",
      "targetFaceOrPolicy": "CDN_HAMCHOB_R",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "\uD568\uCD08\uB871\uBC14\uD0D5",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/gh/projectnoonnu/noonfonts_2104@1.0/HANBatang.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.9f9811ad1c07f0295722.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uD55C\uCEF4\uB3CB\uC6C0",
      "targetFaceOrPolicy": "CDN_HAMCHOD_R",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "\uD55C\uCEF4\uB3CB\uC6C0",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/gh/projectnoonnu/noonfonts_four@1.0/HCRDotum.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.8f74d729519767fbbf93.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uD55C\uCEF4\uBC14\uD0D5",
      "targetFaceOrPolicy": "CDN_HAMCHOB_R",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "\uD55C\uCEF4\uBC14\uD0D5",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/gh/projectnoonnu/noonfonts_2104@1.0/HANBatang.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.768a38c63d8bd590b992.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uD55C\uCEF4\uC0B0\uB73B\uB3CB\uC6C0",
      "targetFaceOrPolicy": "CDN_HAMCHOD_R",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "\uD55C\uCEF4\uC0B0\uB73B\uB3CB\uC6C0",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/gh/projectnoonnu/noonfonts_four@1.0/HCRDotum.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.31eddfa9d17a36b7a95c.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uC0C8\uB3CB\uC6C0",
      "targetFaceOrPolicy": "CDN_HAMCHOD_R",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "\uC0C8\uB3CB\uC6C0",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/gh/projectnoonnu/noonfonts_four@1.0/HCRDotum.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.3ff1312cd22c7187e612.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uC0C8\uBC14\uD0D5",
      "targetFaceOrPolicy": "CDN_HAMCHOB_R",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "\uC0C8\uBC14\uD0D5",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/gh/projectnoonnu/noonfonts_2104@1.0/HANBatang.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.30078d3a0db57db6e3a4.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "HY\uD5E4\uB4DC\uB77C\uC778M",
      "targetFaceOrPolicy": "'fonts/NotoSansKR-Bold.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "HY\uD5E4\uB4DC\uB77C\uC778M",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/NotoSansKR-Bold.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.62f82c6c6e42b2466712.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "HYHeadLine M",
      "targetFaceOrPolicy": "'fonts/NotoSansKR-Bold.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "HYHeadLine M",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/NotoSansKR-Bold.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.e5f20e53cc00a1c7dfd1.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "HYHeadLine Medium",
      "targetFaceOrPolicy": "'fonts/NotoSansKR-Bold.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "HYHeadLine Medium",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/NotoSansKR-Bold.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.86f800aa66064bb9adaf.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "HY\uACAC\uACE0\uB515",
      "targetFaceOrPolicy": "'fonts/NotoSansKR-Bold.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "HY\uACAC\uACE0\uB515",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/NotoSansKR-Bold.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.0cfefc4a25911abc7b28.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "HYGothic-Extra",
      "targetFaceOrPolicy": "'fonts/NotoSansKR-Bold.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "HYGothic-Extra",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/NotoSansKR-Bold.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.94a8953162d2d51c96ba.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "HY\uADF8\uB798\uD53D",
      "targetFaceOrPolicy": "'fonts/NotoSansKR-Regular.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "HY\uADF8\uB798\uD53D",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/NotoSansKR-Regular.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.88a1eb20cd3b549115cb.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "HYGraphic-Medium",
      "targetFaceOrPolicy": "'fonts/NotoSansKR-Regular.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "HYGraphic-Medium",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/NotoSansKR-Regular.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.3753c27802a6697adaca.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "HY\uADF8\uB798\uD53DM",
      "targetFaceOrPolicy": "'fonts/NotoSansKR-Regular.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "HY\uADF8\uB798\uD53DM",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/NotoSansKR-Regular.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.29d6d127a0d52037a7a5.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "HY\uACAC\uBA85\uC870",
      "targetFaceOrPolicy": "'fonts/NotoSerifKR-Bold.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "HY\uACAC\uBA85\uC870",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/NotoSerifKR-Bold.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.833df2e422075c8bd815.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "HYMyeongJo-Extra",
      "targetFaceOrPolicy": "'fonts/NotoSerifKR-Bold.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "HYMyeongJo-Extra",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/NotoSerifKR-Bold.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.93eb9ff639f4cfcfb962.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "HY\uC2E0\uBA85\uC870",
      "targetFaceOrPolicy": "'fonts/NotoSerifKR-Regular.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "HY\uC2E0\uBA85\uC870",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/NotoSerifKR-Regular.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.a34b73718b0ffd09a21b.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "HY\uC911\uACE0\uB515",
      "targetFaceOrPolicy": "'fonts/NotoSansKR-Regular.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "HY\uC911\uACE0\uB515",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/NotoSansKR-Regular.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.856cdf2bb6bf547fb7da.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uD55C\uC591\uC911\uACE0\uB515",
      "targetFaceOrPolicy": "'fonts/NotoSansKR-Regular.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "\uD55C\uC591\uC911\uACE0\uB515",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/NotoSansKR-Regular.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.3ba7f1f7809a833b969a.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uC591\uC7AC\uD2BC\uD2BC\uCCB4B",
      "targetFaceOrPolicy": "'fonts/NotoSansKR-Bold.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "\uC591\uC7AC\uD2BC\uD2BC\uCCB4B",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/NotoSansKR-Bold.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.d988ac8884c2a8beab41.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Malgun Gothic",
      "targetFaceOrPolicy": "'fonts/Pretendard-Regular.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "Malgun Gothic",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/Pretendard-Regular.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.b247488092a350760c80.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB9D1\uC740 \uACE0\uB515",
      "targetFaceOrPolicy": "'fonts/Pretendard-Regular.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "\uB9D1\uC740 \uACE0\uB515",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/Pretendard-Regular.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.f09587c087bbefe58254.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB3CB\uC6C0",
      "targetFaceOrPolicy": "'fonts/NotoSansKR-ExtraLight.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "\uB3CB\uC6C0",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/NotoSansKR-ExtraLight.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.0448add22607e6fabd3d.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB3CB\uC6C0\uCCB4",
      "targetFaceOrPolicy": "'fonts/NotoSansKR-ExtraLight.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "\uB3CB\uC6C0\uCCB4",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/NotoSansKR-ExtraLight.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.26197494604ee7285153.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uAD74\uB9BC",
      "targetFaceOrPolicy": "'fonts/NotoSansKR-ExtraLight.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "\uAD74\uB9BC",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/NotoSansKR-ExtraLight.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.4a2e12a75c84cb081aab.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uAD74\uB9BC\uCCB4",
      "targetFaceOrPolicy": "'fonts/D2Coding-Regular.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "\uAD74\uB9BC\uCCB4",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/D2Coding-Regular.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.ec72133ef5cf9fd282fb.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uC0C8\uAD74\uB9BC",
      "targetFaceOrPolicy": "'fonts/NotoSansKR-ExtraLight.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "\uC0C8\uAD74\uB9BC",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/NotoSansKR-ExtraLight.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.411ce3616959e647602c.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Haansoft Dotum",
      "targetFaceOrPolicy": "'fonts/NotoSansKR-ExtraLight.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "Haansoft Dotum",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/NotoSansKR-ExtraLight.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.c7917f3a4fa439763a33.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uBC14\uD0D5",
      "targetFaceOrPolicy": "'fonts/NotoSerifKR-Regular.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "\uBC14\uD0D5",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/NotoSerifKR-Regular.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.batangche-serif.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uBC14\uD0D5\uCCB4",
      "targetFaceOrPolicy": "'fonts/NotoSerifKR-Regular.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "\uBC14\uD0D5\uCCB4",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/NotoSerifKR-Regular.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.1935f03ba4e1a1890c90.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uAD81\uC11C",
      "targetFaceOrPolicy": "'fonts/GowunBatang-Regular.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "\uAD81\uC11C",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/GowunBatang-Regular.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.85a2d17c39656a68a057.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uAD81\uC11C\uCCB4",
      "targetFaceOrPolicy": "'fonts/GowunBatang-Regular.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "\uAD81\uC11C\uCCB4",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/GowunBatang-Regular.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.1cb50440148d64980dac.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uC0C8\uAD81\uC11C",
      "targetFaceOrPolicy": "'fonts/GowunBatang-Regular.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "\uC0C8\uAD81\uC11C",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/GowunBatang-Regular.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.600e8918afb7dce374f4.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB098\uB214\uACE0\uB515",
      "targetFaceOrPolicy": "'fonts/NanumGothic-Regular.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "\uB098\uB214\uACE0\uB515",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/NanumGothic-Regular.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.3036d5d8cc5c14a890c9.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB098\uB214\uACE0\uB515 Bold",
      "targetFaceOrPolicy": "CDN_NANUM_GOTHIC_BOLD",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "\uB098\uB214\uACE0\uB515 Bold",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/@fontsource/nanum-gothic@5.3.0/files/nanum-gothic-0-700-normal.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.bddb33f3dad691a36c3e.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB098\uB214\uACE0\uB515 ExtraBold",
      "targetFaceOrPolicy": "CDN_NANUM_GOTHIC_EXTRA_BOLD",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "\uB098\uB214\uACE0\uB515 ExtraBold",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/@fontsource/nanum-gothic@5.3.0/files/nanum-gothic-0-800-normal.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.9dacb9d11f184d63edb3.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB098\uB214\uBA85\uC870",
      "targetFaceOrPolicy": "'fonts/NanumMyeongjo-Regular.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "\uB098\uB214\uBA85\uC870",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/NanumMyeongjo-Regular.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.d08686d681c97e128496.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB098\uB214\uBA85\uC870 ExtraBold",
      "targetFaceOrPolicy": "CDN_NANUM_MYEONGJO_EXTRA_BOLD",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "\uB098\uB214\uBA85\uC870 ExtraBold",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/@fontsource/nanum-myeongjo@5.3.0/files/nanum-myeongjo-0-800-normal.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.a85bd10cee9ebd997eee.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB098\uB214\uACE0\uB515\uCF54\uB529",
      "targetFaceOrPolicy": "'fonts/NanumGothicCoding-Regular.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "\uB098\uB214\uACE0\uB515\uCF54\uB529",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/NanumGothicCoding-Regular.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.dd065bb47aec6ca6723d.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB098\uB214\uACE0\uB515_\uCF54\uB529",
      "targetFaceOrPolicy": "'fonts/NanumGothicCoding-Regular.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "\uB098\uB214\uACE0\uB515_\uCF54\uB529",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/NanumGothicCoding-Regular.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.223d8475001285897db8.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "NanumGothic",
      "targetFaceOrPolicy": "'fonts/NanumGothic-Regular.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "NanumGothic",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/NanumGothic-Regular.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.86194ca892a082c950b8.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Palatino Linotype",
      "targetFaceOrPolicy": "'fonts/NotoSerifKR-Regular.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "Palatino Linotype",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/NotoSerifKR-Regular.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.8175c2ae512fdcecc704.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Noto Sans KR",
      "targetFaceOrPolicy": "'fonts/NotoSansKR-Regular.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "Noto Sans KR",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/NotoSansKR-Regular.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.d8acdee5efab4ff80ae7.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Noto Sans KR Medium",
      "targetFaceOrPolicy": "CDN_NOTO_SANS_KR_MEDIUM",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "Noto Sans KR Medium",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/@fontsource/noto-sans-kr@5.3.0/files/noto-sans-kr-0-500-normal.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.370ab90396cbd2cefa67.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Noto Sans KR ExtraLight",
      "targetFaceOrPolicy": "'fonts/NotoSansKR-ExtraLight.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "Noto Sans KR ExtraLight",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/NotoSansKR-ExtraLight.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.16a7ab9887c570ec0d99.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Noto Serif KR",
      "targetFaceOrPolicy": "'fonts/NotoSerifKR-Regular.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "Noto Serif KR",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/NotoSerifKR-Regular.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.746b8c3993b4f81def2c.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Pretendard",
      "targetFaceOrPolicy": "'fonts/Pretendard-Regular.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "Pretendard",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/Pretendard-Regular.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.be1e50dc2beb3d0f60e3.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Pretendard Thin",
      "targetFaceOrPolicy": "'fonts/Pretendard-Thin.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "Pretendard Thin",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/Pretendard-Thin.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.afd86ce934ac67467a43.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Pretendard ExtraLight",
      "targetFaceOrPolicy": "'fonts/Pretendard-ExtraLight.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "Pretendard ExtraLight",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/Pretendard-ExtraLight.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.2121cbb9a8a2c4566a4c.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Pretendard Light",
      "targetFaceOrPolicy": "'fonts/Pretendard-Light.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "Pretendard Light",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/Pretendard-Light.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.37b271c9e695ce40a5c7.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Pretendard Medium",
      "targetFaceOrPolicy": "'fonts/Pretendard-Medium.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "Pretendard Medium",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/Pretendard-Medium.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.e9989f499770a1829563.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Pretendard SemiBold",
      "targetFaceOrPolicy": "'fonts/Pretendard-SemiBold.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "Pretendard SemiBold",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/Pretendard-SemiBold.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.30364eaa2fa741fabe4c.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Pretendard Bold",
      "targetFaceOrPolicy": "'fonts/Pretendard-Bold.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "Pretendard Bold",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/Pretendard-Bold.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.87d8b2801087e772ddb3.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Pretendard ExtraBold",
      "targetFaceOrPolicy": "'fonts/Pretendard-ExtraBold.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "Pretendard ExtraBold",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/Pretendard-ExtraBold.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.eef87dc1aae34a7afc2c.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Pretendard Black",
      "targetFaceOrPolicy": "'fonts/Pretendard-Black.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "Pretendard Black",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/Pretendard-Black.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.5e648d7aa6c2db3be53d.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "DejaVu Serif",
      "targetFaceOrPolicy": "CDN_DEJAVU_SERIF_REGULAR",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "DejaVu Serif",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/@fontsource/dejavu-serif@5.3.0/files/dejavu-serif-latin-400-normal.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.45ef6b86328af59f834c.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Roboto",
      "targetFaceOrPolicy": "CDN_ROBOTO_REGULAR",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "Roboto",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/@fontsource/roboto@5.3.0/files/roboto-latin-400-normal.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.9226454d982d47a1557d.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Government_16040911",
      "targetFaceOrPolicy": "CDN_GOVERNMENT_SYMBOL_REGULAR",
      "conditions": {
        "profile": "canvas2d-css-truetype"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "Government_16040911",
        "format": "truetype",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/gh/jangster77/korea-government-symbol-font@v1.0.0/fonts/Government_16040911.ttf",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.521afff37dd1f6357469.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uC815\uBD80\uC0C1\uC9D5 \uBD80\uCC98\uBA85_16040911",
      "targetFaceOrPolicy": "CDN_GOVERNMENT_SYMBOL_REGULAR",
      "conditions": {
        "profile": "canvas2d-css-truetype"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "\uC815\uBD80\uC0C1\uC9D5 \uBD80\uCC98\uBA85_16040911",
        "format": "truetype",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/gh/jangster77/korea-government-symbol-font@v1.0.0/fonts/Government_16040911.ttf",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.f718d270a6f25396c4af.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPub\uB3CB\uC6C0\uCCB4 Light",
      "targetFaceOrPolicy": "`${CDN_KOPUB}/KoPubDotum-Light.woff`",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "KoPub\uB3CB\uC6C0\uCCB4 Light",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/font-kopub@1.0.2/fonts/KoPubDotum-Light.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.a93f39ddc1e2f413d204.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPub\uB3CB\uC6C0\uCCB4 Medium",
      "targetFaceOrPolicy": "`${CDN_KOPUB}/KoPubDotum-Medium.woff`",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "KoPub\uB3CB\uC6C0\uCCB4 Medium",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/font-kopub@1.0.2/fonts/KoPubDotum-Medium.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.3f2ebfb25f1e24a5e022.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPub\uB3CB\uC6C0\uCCB4 Bold",
      "targetFaceOrPolicy": "`${CDN_KOPUB}/KoPubDotum-Bold.woff`",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "KoPub\uB3CB\uC6C0\uCCB4 Bold",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/font-kopub@1.0.2/fonts/KoPubDotum-Bold.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.bb3cbc04a878dd35803c.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPub\uBC14\uD0D5\uCCB4 Light",
      "targetFaceOrPolicy": "`${CDN_KOPUB}/KoPubBatang-Light.woff`",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "KoPub\uBC14\uD0D5\uCCB4 Light",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/font-kopub@1.0.2/fonts/KoPubBatang-Light.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.c376561582c767a780fd.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPub\uBC14\uD0D5\uCCB4 Medium",
      "targetFaceOrPolicy": "`${CDN_KOPUB}/KoPubBatang-Medium.woff`",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "KoPub\uBC14\uD0D5\uCCB4 Medium",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/font-kopub@1.0.2/fonts/KoPubBatang-Medium.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.898ab998fcc897199dbf.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPub\uBC14\uD0D5\uCCB4 Bold",
      "targetFaceOrPolicy": "`${CDN_KOPUB}/KoPubBatang-Bold.woff`",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "KoPub\uBC14\uD0D5\uCCB4 Bold",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/font-kopub@1.0.2/fonts/KoPubBatang-Bold.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.73bb35832c85fdcfa94a.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubDotum Light",
      "targetFaceOrPolicy": "`${CDN_KOPUB}/KoPubDotum-Light.woff`",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "KoPubDotum Light",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/font-kopub@1.0.2/fonts/KoPubDotum-Light.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.334218b855ae9b9950b4.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubDotum Medium",
      "targetFaceOrPolicy": "`${CDN_KOPUB}/KoPubDotum-Medium.woff`",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "KoPubDotum Medium",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/font-kopub@1.0.2/fonts/KoPubDotum-Medium.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.132bd3983f2110e463bc.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubDotum Bold",
      "targetFaceOrPolicy": "`${CDN_KOPUB}/KoPubDotum-Bold.woff`",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "KoPubDotum Bold",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/font-kopub@1.0.2/fonts/KoPubDotum-Bold.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.8225cfd32925b5ad4dff.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubBatang Light",
      "targetFaceOrPolicy": "`${CDN_KOPUB}/KoPubBatang-Light.woff`",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "KoPubBatang Light",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/font-kopub@1.0.2/fonts/KoPubBatang-Light.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.e2bab0aa777f7c235f74.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubBatang Medium",
      "targetFaceOrPolicy": "`${CDN_KOPUB}/KoPubBatang-Medium.woff`",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "KoPubBatang Medium",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/font-kopub@1.0.2/fonts/KoPubBatang-Medium.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.af8d0ba95e9447ddf7dc.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubBatang Bold",
      "targetFaceOrPolicy": "`${CDN_KOPUB}/KoPubBatang-Bold.woff`",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "KoPubBatang Bold",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/font-kopub@1.0.2/fonts/KoPubBatang-Bold.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.ab5d962141d56102aa59.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubDotumLight",
      "targetFaceOrPolicy": "`${CDN_KOPUB}/KoPubDotum-Light.woff`",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "KoPubDotumLight",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/font-kopub@1.0.2/fonts/KoPubDotum-Light.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.11811dc7b4887de84937.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubDotumMedium",
      "targetFaceOrPolicy": "`${CDN_KOPUB}/KoPubDotum-Medium.woff`",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "KoPubDotumMedium",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/font-kopub@1.0.2/fonts/KoPubDotum-Medium.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.444dd63f80256eed471d.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubDotumBold",
      "targetFaceOrPolicy": "`${CDN_KOPUB}/KoPubDotum-Bold.woff`",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "KoPubDotumBold",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/font-kopub@1.0.2/fonts/KoPubDotum-Bold.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.92f6e5d4c44c53d9171a.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubBatangLight",
      "targetFaceOrPolicy": "`${CDN_KOPUB}/KoPubBatang-Light.woff`",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "KoPubBatangLight",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/font-kopub@1.0.2/fonts/KoPubBatang-Light.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.2fe9515d279228acacee.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubBatangMedium",
      "targetFaceOrPolicy": "`${CDN_KOPUB}/KoPubBatang-Medium.woff`",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "KoPubBatangMedium",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/font-kopub@1.0.2/fonts/KoPubBatang-Medium.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.8a53670839d0037b5b6c.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubBatangBold",
      "targetFaceOrPolicy": "`${CDN_KOPUB}/KoPubBatang-Bold.woff`",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "KoPubBatangBold",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/font-kopub@1.0.2/fonts/KoPubBatang-Bold.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.b4a81472cc52c505ee6d.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubWorld\uB3CB\uC6C0\uCCB4 Light",
      "targetFaceOrPolicy": "`${CDN_KOPUB_WORLD}/KoPubWorld-Dotum-Light.woff2`",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "KoPubWorld\uB3CB\uC6C0\uCCB4 Light",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/font-kopubworld@1.0.3/fonts/KoPubWorld-Dotum-Light.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.275188318957f26d8f80.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubWorld\uB3CB\uC6C0\uCCB4 Medium",
      "targetFaceOrPolicy": "`${CDN_KOPUB_WORLD}/KoPubWorld-Dotum-Medium.woff2`",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "KoPubWorld\uB3CB\uC6C0\uCCB4 Medium",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/font-kopubworld@1.0.3/fonts/KoPubWorld-Dotum-Medium.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.1e957b44174bb4e58a05.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubWorld\uB3CB\uC6C0\uCCB4 Bold",
      "targetFaceOrPolicy": "`${CDN_KOPUB_WORLD}/KoPubWorld-Dotum-Bold.woff2`",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "KoPubWorld\uB3CB\uC6C0\uCCB4 Bold",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/font-kopubworld@1.0.3/fonts/KoPubWorld-Dotum-Bold.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.272f0ba64ebeef347d44.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubWorld\uBC14\uD0D5\uCCB4 Light",
      "targetFaceOrPolicy": "`${CDN_KOPUB_WORLD}/KoPubWorld-Batang-Light.woff2`",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "KoPubWorld\uBC14\uD0D5\uCCB4 Light",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/font-kopubworld@1.0.3/fonts/KoPubWorld-Batang-Light.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.81125e4480d6704cd407.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubWorld\uBC14\uD0D5\uCCB4 Medium",
      "targetFaceOrPolicy": "`${CDN_KOPUB_WORLD}/KoPubWorld-Batang-Medium.woff2`",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "KoPubWorld\uBC14\uD0D5\uCCB4 Medium",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/font-kopubworld@1.0.3/fonts/KoPubWorld-Batang-Medium.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.0c50fe05921a7c299e56.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubWorld\uBC14\uD0D5\uCCB4 Bold",
      "targetFaceOrPolicy": "`${CDN_KOPUB_WORLD}/KoPubWorld-Batang-Bold.woff2`",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "KoPubWorld\uBC14\uD0D5\uCCB4 Bold",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/font-kopubworld@1.0.3/fonts/KoPubWorld-Batang-Bold.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.4acaa1b1c7544f6b8ffd.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubWorld Dotum",
      "targetFaceOrPolicy": "`${CDN_KOPUB_WORLD}/KoPubWorld-Dotum-Medium.woff2`",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "KoPubWorld Dotum",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/font-kopubworld@1.0.3/fonts/KoPubWorld-Dotum-Medium.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.675b1aec7f8844bb0897.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubWorld Batang",
      "targetFaceOrPolicy": "`${CDN_KOPUB_WORLD}/KoPubWorld-Batang-Medium.woff2`",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "KoPubWorld Batang",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/font-kopubworld@1.0.3/fonts/KoPubWorld-Batang-Medium.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.bdc440581b1fca926d22.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubWorldDotum",
      "targetFaceOrPolicy": "`${CDN_KOPUB_WORLD}/KoPubWorld-Dotum-Medium.woff2`",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "KoPubWorldDotum",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/font-kopubworld@1.0.3/fonts/KoPubWorld-Dotum-Medium.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.32defe91e23de06f16c4.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubWorldBatang",
      "targetFaceOrPolicy": "`${CDN_KOPUB_WORLD}/KoPubWorld-Batang-Medium.woff2`",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "KoPubWorldBatang",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/font-kopubworld@1.0.3/fonts/KoPubWorld-Batang-Medium.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.977ef99cd33d09129a6b.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uACBD\uAE30\uCC9C\uB144\uBC14\uD0D5 Bold",
      "targetFaceOrPolicy": "`${CDN_GYEONGGI_MILLENNIUM}/Batang_Regular.woff`",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "\uACBD\uAE30\uCC9C\uB144\uBC14\uD0D5 Bold",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/gh/projectnoonnu/2410-3@1.0/Batang_Regular.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.2041f33491f87ddee0af.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uACBD\uAE30\uCC9C\uB144\uBC14\uD0D5 Regular",
      "targetFaceOrPolicy": "`${CDN_GYEONGGI_MILLENNIUM}/Batang_Regular.woff`",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "\uACBD\uAE30\uCC9C\uB144\uBC14\uD0D5 Regular",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/gh/projectnoonnu/2410-3@1.0/Batang_Regular.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.f14e188b83ef32e773dd.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uACBD\uAE30\uCC9C\uB144\uC81C\uBAA9 Bold",
      "targetFaceOrPolicy": "`${CDN_GYEONGGI_MILLENNIUM}/Title_Medium.woff`",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "\uACBD\uAE30\uCC9C\uB144\uC81C\uBAA9 Bold",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/gh/projectnoonnu/2410-3@1.0/Title_Medium.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.baf9ef5d6088912b069e.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uACBD\uAE30\uCC9C\uB144\uC81C\uBAA9 Light",
      "targetFaceOrPolicy": "`${CDN_GYEONGGI_MILLENNIUM}/Title_Medium.woff`",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "\uACBD\uAE30\uCC9C\uB144\uC81C\uBAA9 Light",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/gh/projectnoonnu/2410-3@1.0/Title_Medium.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.afdb1042b3e581761dd7.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uACBD\uAE30\uCC9C\uB144\uC81C\uBAA9 Medium",
      "targetFaceOrPolicy": "`${CDN_GYEONGGI_MILLENNIUM}/Title_Medium.woff`",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "\uACBD\uAE30\uCC9C\uB144\uC81C\uBAA9 Medium",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/gh/projectnoonnu/2410-3@1.0/Title_Medium.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.24c7a7ed92e76b838f70.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB098\uB214\uBC14\uB978\uD39C",
      "targetFaceOrPolicy": "`${CDN_NOONFONTS_TWO}/NanumBarunpen.woff`",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "\uB098\uB214\uBC14\uB978\uD39C",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/gh/projectnoonnu/noonfonts_two@1.0/NanumBarunpen.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.fe8c1e6bd80dc977481a.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB098\uB214\uC2A4\uD018\uC5B4\uB77C\uC6B4\uB4DC Bold",
      "targetFaceOrPolicy": "`${CDN_NOONFONTS_TWO}/NanumSquareRound.woff`",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "\uB098\uB214\uC2A4\uD018\uC5B4\uB77C\uC6B4\uB4DC Bold",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/gh/projectnoonnu/noonfonts_two@1.0/NanumSquareRound.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.a2fca4b269cbaf47e6fd.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB098\uB214\uC2A4\uD018\uC5B4\uB77C\uC6B4\uB4DC ExtraBold",
      "targetFaceOrPolicy": "`${CDN_NOONFONTS_TWO}/NanumSquareRound.woff`",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "\uB098\uB214\uC2A4\uD018\uC5B4\uB77C\uC6B4\uB4DC ExtraBold",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/gh/projectnoonnu/noonfonts_two@1.0/NanumSquareRound.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.e0e80a5e2d2d694ead20.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB098\uB214\uC2A4\uD018\uC5B4\uB77C\uC6B4\uB4DC Regular",
      "targetFaceOrPolicy": "`${CDN_NOONFONTS_TWO}/NanumSquareRound.woff`",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "\uB098\uB214\uC2A4\uD018\uC5B4\uB77C\uC6B4\uB4DC Regular",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/gh/projectnoonnu/noonfonts_two@1.0/NanumSquareRound.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.ed221d8bc824fdeed8a4.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "62570\uCCB4",
      "targetFaceOrPolicy": "'https://cdn.jsdelivr.net/npm/@noonnu/62570che@0.1.0/fonts/62570-normal.woff'",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "62570\uCCB4",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/@noonnu/62570che@0.1.0/fonts/62570-normal.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.853f0809eee4e6b9daa9.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB098\uB214\uACE0\uB515 Light",
      "targetFaceOrPolicy": "'https://cdn.jsdelivr.net/npm/@fontsource/nanum-gothic@5.3.0/files/nanum-gothic-0-400-normal.woff'",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "\uB098\uB214\uACE0\uB515 Light",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/@fontsource/nanum-gothic@5.3.0/files/nanum-gothic-0-400-normal.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.66778cab409e2f8a43e1.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB098\uB214\uACE0\uB515OTF",
      "targetFaceOrPolicy": "'https://cdn.jsdelivr.net/npm/@kfonts/nanum-gothic-otf@0.2.0/src/NanumGothic.otf'",
      "conditions": {
        "profile": "canvas2d-css-opentype"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "\uB098\uB214\uACE0\uB515OTF",
        "format": "opentype",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/@kfonts/nanum-gothic-otf@0.2.0/src/NanumGothic.otf",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.64deb67e642ac428998b.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB098\uB214\uACE0\uB515OTF Bold",
      "targetFaceOrPolicy": "'https://cdn.jsdelivr.net/npm/@kfonts/nanum-gothic-otf@0.2.0/src/NanumGothicBold.otf'",
      "conditions": {
        "profile": "canvas2d-css-opentype"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "\uB098\uB214\uACE0\uB515OTF Bold",
        "format": "opentype",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/@kfonts/nanum-gothic-otf@0.2.0/src/NanumGothicBold.otf",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.f934e40df33952c15e3d.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB098\uB214\uBA85\uC870OTF ExtraBold",
      "targetFaceOrPolicy": "'https://cdn.jsdelivr.net/npm/@kfonts/nanum-myeongjo-otf@0.2.0/src/NanumMyeongjoExtraBold.otf'",
      "conditions": {
        "profile": "canvas2d-css-opentype"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "\uB098\uB214\uBA85\uC870OTF ExtraBold",
        "format": "opentype",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/@kfonts/nanum-myeongjo-otf@0.2.0/src/NanumMyeongjoExtraBold.otf",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.daeb146a5a3125ba10ff.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB098\uB214\uBC14\uB978\uACE0\uB515 Light",
      "targetFaceOrPolicy": "'https://cdn.jsdelivr.net/npm/@kfonts/nanum-barun-gothic@0.3.0/NanumBarunGothicLight.woff'",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "\uB098\uB214\uBC14\uB978\uACE0\uB515 Light",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/@kfonts/nanum-barun-gothic@0.3.0/NanumBarunGothicLight.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.d0ae1415680a6333f9d3.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB098\uB214\uBC14\uB978\uACE0\uB515OTF",
      "targetFaceOrPolicy": "'https://cdn.jsdelivr.net/npm/@kfonts/nanum-barun-gothic-yet-hangul-otf@0.2.0/src/NanumBarunGothic-YetHangul.otf'",
      "conditions": {
        "profile": "canvas2d-css-opentype"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "\uB098\uB214\uBC14\uB978\uACE0\uB515OTF",
        "format": "opentype",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/@kfonts/nanum-barun-gothic-yet-hangul-otf@0.2.0/src/NanumBarunGothic-YetHangul.otf",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.3bb7acf78e4978622599.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB098\uB214\uC2A4\uD018\uC5B4OTF",
      "targetFaceOrPolicy": "'https://cdn.jsdelivr.net/npm/@kfonts/nanum-square-otf@0.2.0/src/NanumSquareB.otf'",
      "conditions": {
        "profile": "canvas2d-css-opentype"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "\uB098\uB214\uC2A4\uD018\uC5B4OTF",
        "format": "opentype",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/@kfonts/nanum-square-otf@0.2.0/src/NanumSquareB.otf",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.4b6852096db05e93c258.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB2E4\uC74C_SemiBold",
      "targetFaceOrPolicy": "'https://cdn.jsdelivr.net/npm/alibabapuhuiti-3-75-semibold@1.0.0/AlibabaPuHuiTi-3-75-SemiBold.otf'",
      "conditions": {
        "profile": "canvas2d-css-opentype"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "\uB2E4\uC74C_SemiBold",
        "format": "opentype",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/alibabapuhuiti-3-75-semibold@1.0.0/AlibabaPuHuiTi-3-75-SemiBold.otf",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.fda1a51097546a80890b.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uC5D0\uC2A4\uCF54\uC5B4 \uB4DC\uB9BC 3 Light",
      "targetFaceOrPolicy": "'https://cdn.jsdelivr.net/npm/@noonnu/s-core-dream-3-light@0.1.0/fonts/s-coredream-3light-normal.woff'",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "\uC5D0\uC2A4\uCF54\uC5B4 \uB4DC\uB9BC 3 Light",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/@noonnu/s-core-dream-3-light@0.1.0/fonts/s-coredream-3light-normal.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.829e641bf7d97c4b41e3.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Baskerville BT",
      "targetFaceOrPolicy": "'https://cdn.jsdelivr.net/npm/@fontsource/libre-baskerville@5.3.0/files/libre-baskerville-latin-400-italic.woff'",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "Baskerville BT",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/@fontsource/libre-baskerville@5.3.0/files/libre-baskerville-latin-400-italic.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.ed00e50e6310822e1a16.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Bodoni Bd BT",
      "targetFaceOrPolicy": "'https://cdn.jsdelivr.net/npm/@fontsource/bodoni-moda@5.3.0/files/bodoni-moda-latin-400-italic.woff'",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "Bodoni Bd BT",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/@fontsource/bodoni-moda@5.3.0/files/bodoni-moda-latin-400-italic.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.a24633a420802036ba08.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Bodoni Bk BT",
      "targetFaceOrPolicy": "'https://cdn.jsdelivr.net/npm/@fontsource/bodoni-moda@5.3.0/files/bodoni-moda-latin-400-italic.woff'",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "Bodoni Bk BT",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/@fontsource/bodoni-moda@5.3.0/files/bodoni-moda-latin-400-italic.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.66b7fa1b21caa72ae8b5.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Bodoni MT",
      "targetFaceOrPolicy": "'https://cdn.jsdelivr.net/npm/@fontsource/bodoni-moda@5.3.0/files/bodoni-moda-latin-400-italic.woff'",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "Bodoni MT",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/@fontsource/bodoni-moda@5.3.0/files/bodoni-moda-latin-400-italic.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.f9b7ce3f9ecfedc26c08.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "BrushScript BT",
      "targetFaceOrPolicy": "'https://cdn.jsdelivr.net/npm/@fontsource/nanum-brush-script@5.3.0/files/nanum-brush-script-0-400-normal.woff'",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "BrushScript BT",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/@fontsource/nanum-brush-script@5.3.0/files/nanum-brush-script-0-400-normal.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.6a68839caf882e5c47f9.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Calisto MT",
      "targetFaceOrPolicy": "'https://cdn.jsdelivr.net/npm/@fontsource/calistoga@5.3.0/files/calistoga-latin-400-normal.woff'",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "Calisto MT",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/@fontsource/calistoga@5.3.0/files/calistoga-latin-400-normal.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.a3ab877d557ae3620dc9.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Century Schoolbook",
      "targetFaceOrPolicy": "'https://cdn.jsdelivr.net/npm/centschbook-mono@3.2.1/Century-Schoolbook-Monospace-BT.ttf'",
      "conditions": {
        "profile": "canvas2d-css-truetype"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "Century Schoolbook",
        "format": "truetype",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/centschbook-mono@3.2.1/Century-Schoolbook-Monospace-BT.ttf",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.901b6b211f4fcfa54768.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "FangSong",
      "targetFaceOrPolicy": "'https://cdn.jsdelivr.net/npm/@fontpkg/zhuque-fangsong-technical-preview@0.212.0/ZhuqueFangsong-Regular.ttf'",
      "conditions": {
        "profile": "canvas2d-css-truetype"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "FangSong",
        "format": "truetype",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/@fontpkg/zhuque-fangsong-technical-preview@0.212.0/ZhuqueFangsong-Regular.ttf",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.15884b9e7c1f2a7c4ee9.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Futura Hv BT",
      "targetFaceOrPolicy": "'https://cdn.jsdelivr.net/npm/futura-font@1.0.0/FuturaBT-Medium.ttf'",
      "conditions": {
        "profile": "canvas2d-css-truetype"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "Futura Hv BT",
        "format": "truetype",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/futura-font@1.0.0/FuturaBT-Medium.ttf",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.64ceaf9e0bb28ae5c942.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Garamond",
      "targetFaceOrPolicy": "'https://cdn.jsdelivr.net/npm/@fontsource/cormorant-garamond@5.3.0/files/cormorant-garamond-cyrillic-300-italic.woff'",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "Garamond",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/@fontsource/cormorant-garamond@5.3.0/files/cormorant-garamond-cyrillic-300-italic.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.2ce5d402e8711133d375.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "HCRDotum",
      "targetFaceOrPolicy": "'https://cdn.jsdelivr.net/npm/@noonnu/hcr-dotum@0.1.0/fonts/hcrdotum-normal.woff'",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "HCRDotum",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/@noonnu/hcr-dotum@0.1.0/fonts/hcrdotum-normal.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.9c94b159bdd08dbaa68f.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Helvetica",
      "targetFaceOrPolicy": "'https://cdn.jsdelivr.net/npm/helvetica-original@1.0.0/Black/Helvetica-Black.ttf'",
      "conditions": {
        "profile": "canvas2d-css-truetype"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "Helvetica",
        "format": "truetype",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/helvetica-original@1.0.0/Black/Helvetica-Black.ttf",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.4ec2b847f6c75730609a.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Helvetica 65 Medium",
      "targetFaceOrPolicy": "'https://cdn.jsdelivr.net/npm/@duppla-font/helvetica-now@1.0.0/files/HelveticaNowTextMedium.otf'",
      "conditions": {
        "profile": "canvas2d-css-opentype"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "Helvetica 65 Medium",
        "format": "opentype",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/@duppla-font/helvetica-now@1.0.0/files/HelveticaNowTextMedium.otf",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.0d9e89207f8f7d90215a.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Helvetica Neue",
      "targetFaceOrPolicy": "'https://cdn.jsdelivr.net/npm/@marcius-studio/font@0.0.1/HelveticaNeueCyr/HelveticaNeueCyr-Black.ttf'",
      "conditions": {
        "profile": "canvas2d-css-truetype"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "Helvetica Neue",
        "format": "truetype",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/@marcius-studio/font@0.0.1/HelveticaNeueCyr/HelveticaNeueCyr-Black.ttf",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.55003aecf83027a605cd.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KBIZ\uD55C\uB9C8\uC74C\uBA85\uC870 R",
      "targetFaceOrPolicy": "'https://cdn.jsdelivr.net/npm/@noonnu/kbiz-hanmaum-myungjo@0.1.0/fonts/kbizhanmaummyungjo-normal.woff'",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "KBIZ\uD55C\uB9C8\uC74C\uBA85\uC870 R",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/@noonnu/kbiz-hanmaum-myungjo@0.1.0/fonts/kbizhanmaummyungjo-normal.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.7c1ae0bbafc6cdefe9af.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "MS Gothic",
      "targetFaceOrPolicy": "'https://cdn.jsdelivr.net/npm/@fontsource/zen-maru-gothic@5.3.0/files/zen-maru-gothic-10-300-normal.woff'",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "MS Gothic",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/@fontsource/zen-maru-gothic@5.3.0/files/zen-maru-gothic-10-300-normal.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.095c1c232dbb4dfb5cc2.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "MS Mincho",
      "targetFaceOrPolicy": "'https://cdn.jsdelivr.net/npm/@fontsource/shippori-mincho@5.3.0/files/shippori-mincho-0-400-normal.woff'",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "MS Mincho",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/@fontsource/shippori-mincho@5.3.0/files/shippori-mincho-0-400-normal.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.d3e8b09ed17746beaa6a.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "MS Song",
      "targetFaceOrPolicy": "'https://cdn.jsdelivr.net/npm/@fontsource/song-myung@5.3.0/files/song-myung-10-400-normal.woff'",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "MS Song",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/@fontsource/song-myung@5.3.0/files/song-myung-10-400-normal.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.f3ea7acc996fe24a3604.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "MS UI Gothic",
      "targetFaceOrPolicy": "'https://cdn.jsdelivr.net/npm/@fontsource/zen-maru-gothic@5.3.0/files/zen-maru-gothic-10-300-normal.woff'",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "MS UI Gothic",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/@fontsource/zen-maru-gothic@5.3.0/files/zen-maru-gothic-10-300-normal.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.3c6f59d992a9c3bc6797.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "MT Extra",
      "targetFaceOrPolicy": "'https://cdn.jsdelivr.net/npm/@fontsource/fira-sans-extra-condensed@5.3.0/files/fira-sans-extra-condensed-cyrillic-100-italic.woff'",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "MT Extra",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/@fontsource/fira-sans-extra-condensed@5.3.0/files/fira-sans-extra-condensed-cyrillic-100-italic.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.617b2457d3e4b9fef10f.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Myeongjo",
      "targetFaceOrPolicy": "'https://cdn.jsdelivr.net/npm/@fontsource/nanum-myeongjo@5.3.0/files/nanum-myeongjo-0-400-normal.woff'",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "Myeongjo",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/@fontsource/nanum-myeongjo@5.3.0/files/nanum-myeongjo-0-400-normal.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.41f4abc361abb59f405b.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Nanum Barun Gothic",
      "targetFaceOrPolicy": "'https://cdn.jsdelivr.net/npm/@kfonts/nanum-barun-gothic@0.3.0/NanumBarunGothic.woff'",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "Nanum Barun Gothic",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/@kfonts/nanum-barun-gothic@0.3.0/NanumBarunGothic.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.f8bd9d02732ea351cd32.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Noto",
      "targetFaceOrPolicy": "'https://cdn.jsdelivr.net/npm/@fontsource/noto-sans-jp@5.3.0/files/noto-sans-jp-0-100-normal.woff'",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "Noto",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/@fontsource/noto-sans-jp@5.3.0/files/noto-sans-jp-0-100-normal.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.255312354238713953d0.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Noto Sans CJK JP Regular",
      "targetFaceOrPolicy": "'https://cdn.jsdelivr.net/npm/noto-sans-cjk-jp@1.0.1/fonts/NotoSansCJKjp-Regular.woff'",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "Noto Sans CJK JP Regular",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/noto-sans-cjk-jp@1.0.1/fonts/NotoSansCJKjp-Regular.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.95f9511d889a697b4c8a.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Segoe UI",
      "targetFaceOrPolicy": "'https://cdn.jsdelivr.net/npm/@fontpkg/segoe-ui@5.67.0/segoeui.ttf'",
      "conditions": {
        "profile": "canvas2d-css-truetype"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "Segoe UI",
        "format": "truetype",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/@fontpkg/segoe-ui@5.67.0/segoeui.ttf",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.5d2cb1564c2f5ad4dcd6.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "SimSun",
      "targetFaceOrPolicy": "'https://cdn.jsdelivr.net/npm/react-native-font-sim@2.0.1/fonts/SimSun.ttf'",
      "conditions": {
        "profile": "canvas2d-css-truetype"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "SimSun",
        "format": "truetype",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/react-native-font-sim@2.0.1/fonts/SimSun.ttf",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.c52db9881ba457f5c392.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Yu Mincho",
      "targetFaceOrPolicy": "'https://cdn.jsdelivr.net/npm/@fontsource/shippori-mincho@5.3.0/files/shippori-mincho-0-400-normal.woff'",
      "conditions": {
        "profile": "canvas2d-css-woff"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": true,
        "fontFamily": "Yu Mincho",
        "format": "woff",
        "kind": "canvas2d-webfont",
        "sourceUrl": "https://cdn.jsdelivr.net/npm/@fontsource/shippori-mincho@5.3.0/files/shippori-mincho-0-400-normal.woff",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.95f071bf284bacec28b6.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "D2Coding",
      "targetFaceOrPolicy": "'fonts/D2Coding-Regular.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "D2Coding",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/D2Coding-Regular.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.89fc1e92518accb512a3.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uD574\uD53C\uB2C8\uC2A4 \uC0B0\uC2A4 \uB808\uADE4\uB7EC",
      "targetFaceOrPolicy": "'fonts/Happiness-Sans-Regular.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "\uD574\uD53C\uB2C8\uC2A4 \uC0B0\uC2A4 \uB808\uADE4\uB7EC",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/Happiness-Sans-Regular.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.7fa94fcf4b29abfb99e2.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Happiness Sans Regular",
      "targetFaceOrPolicy": "'fonts/Happiness-Sans-Regular.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "Happiness Sans Regular",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/Happiness-Sans-Regular.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.9f0b2b27b2e1cdcf48c9.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uD574\uD53C\uB2C8\uC2A4 \uC0B0\uC2A4 \uBCFC\uB4DC",
      "targetFaceOrPolicy": "'fonts/Happiness-Sans-Bold.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "\uD574\uD53C\uB2C8\uC2A4 \uC0B0\uC2A4 \uBCFC\uB4DC",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/Happiness-Sans-Bold.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.ed42872fd0faa00ab14c.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Happiness Sans Bold",
      "targetFaceOrPolicy": "'fonts/Happiness-Sans-Bold.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "Happiness Sans Bold",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/Happiness-Sans-Bold.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.a98320b11ca23a757549.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uD574\uD53C\uB2C8\uC2A4 \uC0B0\uC2A4 \uD0C0\uC774\uD2C0",
      "targetFaceOrPolicy": "'fonts/Happiness-Sans-Title.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "\uD574\uD53C\uB2C8\uC2A4 \uC0B0\uC2A4 \uD0C0\uC774\uD2C0",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/Happiness-Sans-Title.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.235d312a1bcaa5223d51.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Happiness Sans Title",
      "targetFaceOrPolicy": "'fonts/Happiness-Sans-Title.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "Happiness Sans Title",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/Happiness-Sans-Title.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.7addb14ca54d3478ff11.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uD574\uD53C\uB2C8\uC2A4 \uC0B0\uC2A4 VF",
      "targetFaceOrPolicy": "'fonts/HappinessSansVF.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "\uD574\uD53C\uB2C8\uC2A4 \uC0B0\uC2A4 VF",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/HappinessSansVF.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.6ed322eba70a28f851f5.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Happiness Sans VF",
      "targetFaceOrPolicy": "'fonts/HappinessSansVF.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "Happiness Sans VF",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/HappinessSansVF.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.064b5392c04262fb4a31.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Cafe24 Ssurround Bold",
      "targetFaceOrPolicy": "'fonts/Cafe24Ssurround-v2.0.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "Cafe24 Ssurround Bold",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/Cafe24Ssurround-v2.0.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.9e9d6be2e5d060c37893.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uCE74\uD39824 \uC288\uD37C\uB9E4\uC9C1",
      "targetFaceOrPolicy": "'fonts/Cafe24Supermagic-Regular-v1.0.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "\uCE74\uD39824 \uC288\uD37C\uB9E4\uC9C1",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/Cafe24Supermagic-Regular-v1.0.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.cadf006c804cd692d83d.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Cafe24 Supermagic",
      "targetFaceOrPolicy": "'fonts/Cafe24Supermagic-Regular-v1.0.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "Cafe24 Supermagic",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/Cafe24Supermagic-Regular-v1.0.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.fb1ba6d9a29aa201f8ee.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Latin Modern Math",
      "targetFaceOrPolicy": "'fonts/LatinModernMath-Regular.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "Latin Modern Math",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/LatinModernMath-Regular.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.217e88329fd93b1b4b7d.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "SpoqaHanSans",
      "targetFaceOrPolicy": "'fonts/SpoqaHanSans-Regular.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "SpoqaHanSans",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/SpoqaHanSans-Regular.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.5031552686798f2c6ca4.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uACE0\uC6B4\uBC14\uD0D5",
      "targetFaceOrPolicy": "'fonts/GowunBatang-Regular.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "\uACE0\uC6B4\uBC14\uD0D5",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/GowunBatang-Regular.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.673ef286e7424d121b88.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uACE0\uC6B4\uB3CB\uC6C0",
      "targetFaceOrPolicy": "'fonts/GowunDodum-Regular.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "\uACE0\uC6B4\uB3CB\uC6C0",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/GowunDodum-Regular.woff2",
        "unicodeRange": null
      }
    },
    {
      "ruleId": "rule.studio-supply.0aab2d58429b52047acb.canvas2d",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Source Han Serif K Old Hangul",
      "targetFaceOrPolicy": "'fonts/SourceHanSerifK-OldHangul-subset.woff2'",
      "conditions": {
        "profile": "canvas2d-css-unknown"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "external": false,
        "fontFamily": "Source Han Serif K Old Hangul",
        "format": "woff2",
        "kind": "canvas2d-webfont",
        "sourceUrl": "fonts/SourceHanSerifK-OldHangul-subset.woff2",
        "unicodeRange": "U+1100-11FF, U+A960-A97F, U+D7B0-D7FF"
      }
    }
  ]);

  // build.noindex/task567/stage3-2/upstream-v087/rhwp-studio/src/core/generated/font-rule-projections/canvaskit-sfnt.ts
  var FONT_RULE_CANVASKIT_SFNT_META = Object.freeze({
    "schemaVersion": "1.0",
    "sourceCommit": "a1f9872e28aea6755b656161ed1802f73308da58",
    "inputSha256": "a94b64311540ff736c7eb89a70dc3ce38742fdd671ec3c73a4ee05b1302be034",
    "projectionId": "canvaskit-sfnt",
    "projectionSha256": "d9019fc756d4fd9334252704309bb2020c251d6a7d04dc0f5a6b2efb0f017668",
    "ruleCount": 158
  });
  var FONT_RULE_CANVASKIT_SFNT_RULES = Object.freeze([
    {
      "ruleId": "rule.studio-supply.bd74329daa5a2a185478.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uD568\uCD08\uB86C\uB3CB\uC6C0",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for CDN_HAMCHOD_R",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uD568\uCD08\uB86C\uB3CB\uC6C0",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "\uD568\uCD08\uB86C\uB3CB\uC6C0"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uC0C8\uB3CB\uC6C0",
                "\uD55C\uCEF4\uB3CB\uC6C0",
                "\uD55C\uCEF4\uC0B0\uB73B\uB3CB\uC6C0",
                "\uD568\uCD08\uB86C\uB3CB\uC6C0",
                "\uD568\uCD08\uB871\uB3CB\uC6C0"
              ],
              "url": "https://cdn.jsdelivr.net/gh/projectnoonnu/noonfonts_four@1.0/HCRDotum.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.05ea00b9c9e0a769922f.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uD568\uCD08\uB86C\uBC14\uD0D5",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for CDN_HAMCHOB_R",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uD568\uCD08\uB86C\uBC14\uD0D5",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "\uD568\uCD08\uB86C\uBC14\uD0D5"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uC0C8\uBC14\uD0D5",
                "\uD55C\uCEF4\uBC14\uD0D5",
                "\uD568\uCD08\uB86C\uBC14\uD0D5",
                "\uD568\uCD08\uB871\uBC14\uD0D5"
              ],
              "url": "https://cdn.jsdelivr.net/gh/projectnoonnu/noonfonts_2104@1.0/HANBatang.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.bc675f06812aac14a681.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uD568\uCD08\uB871\uB3CB\uC6C0",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for CDN_HAMCHOD_R",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uD568\uCD08\uB871\uB3CB\uC6C0",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "\uD568\uCD08\uB871\uB3CB\uC6C0"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uC0C8\uB3CB\uC6C0",
                "\uD55C\uCEF4\uB3CB\uC6C0",
                "\uD55C\uCEF4\uC0B0\uB73B\uB3CB\uC6C0",
                "\uD568\uCD08\uB86C\uB3CB\uC6C0",
                "\uD568\uCD08\uB871\uB3CB\uC6C0"
              ],
              "url": "https://cdn.jsdelivr.net/gh/projectnoonnu/noonfonts_four@1.0/HCRDotum.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.54d07bcc1a0df04ff7dc.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uD568\uCD08\uB871\uBC14\uD0D5",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for CDN_HAMCHOB_R",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uD568\uCD08\uB871\uBC14\uD0D5",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "\uD568\uCD08\uB871\uBC14\uD0D5"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uC0C8\uBC14\uD0D5",
                "\uD55C\uCEF4\uBC14\uD0D5",
                "\uD568\uCD08\uB86C\uBC14\uD0D5",
                "\uD568\uCD08\uB871\uBC14\uD0D5"
              ],
              "url": "https://cdn.jsdelivr.net/gh/projectnoonnu/noonfonts_2104@1.0/HANBatang.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.9f9811ad1c07f0295722.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uD55C\uCEF4\uB3CB\uC6C0",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for CDN_HAMCHOD_R",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uD55C\uCEF4\uB3CB\uC6C0",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "\uD55C\uCEF4\uB3CB\uC6C0"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uC0C8\uB3CB\uC6C0",
                "\uD55C\uCEF4\uB3CB\uC6C0",
                "\uD55C\uCEF4\uC0B0\uB73B\uB3CB\uC6C0",
                "\uD568\uCD08\uB86C\uB3CB\uC6C0",
                "\uD568\uCD08\uB871\uB3CB\uC6C0"
              ],
              "url": "https://cdn.jsdelivr.net/gh/projectnoonnu/noonfonts_four@1.0/HCRDotum.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.8f74d729519767fbbf93.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uD55C\uCEF4\uBC14\uD0D5",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for CDN_HAMCHOB_R",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uD55C\uCEF4\uBC14\uD0D5",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "\uD55C\uCEF4\uBC14\uD0D5"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uC0C8\uBC14\uD0D5",
                "\uD55C\uCEF4\uBC14\uD0D5",
                "\uD568\uCD08\uB86C\uBC14\uD0D5",
                "\uD568\uCD08\uB871\uBC14\uD0D5"
              ],
              "url": "https://cdn.jsdelivr.net/gh/projectnoonnu/noonfonts_2104@1.0/HANBatang.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.768a38c63d8bd590b992.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uD55C\uCEF4\uC0B0\uB73B\uB3CB\uC6C0",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for CDN_HAMCHOD_R",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uD55C\uCEF4\uC0B0\uB73B\uB3CB\uC6C0",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "\uD55C\uCEF4\uC0B0\uB73B\uB3CB\uC6C0"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uC0C8\uB3CB\uC6C0",
                "\uD55C\uCEF4\uB3CB\uC6C0",
                "\uD55C\uCEF4\uC0B0\uB73B\uB3CB\uC6C0",
                "\uD568\uCD08\uB86C\uB3CB\uC6C0",
                "\uD568\uCD08\uB871\uB3CB\uC6C0"
              ],
              "url": "https://cdn.jsdelivr.net/gh/projectnoonnu/noonfonts_four@1.0/HCRDotum.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.31eddfa9d17a36b7a95c.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uC0C8\uB3CB\uC6C0",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for CDN_HAMCHOD_R",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uC0C8\uB3CB\uC6C0",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "\uC0C8\uB3CB\uC6C0"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uC0C8\uB3CB\uC6C0",
                "\uD55C\uCEF4\uB3CB\uC6C0",
                "\uD55C\uCEF4\uC0B0\uB73B\uB3CB\uC6C0",
                "\uD568\uCD08\uB86C\uB3CB\uC6C0",
                "\uD568\uCD08\uB871\uB3CB\uC6C0"
              ],
              "url": "https://cdn.jsdelivr.net/gh/projectnoonnu/noonfonts_four@1.0/HCRDotum.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.3ff1312cd22c7187e612.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uC0C8\uBC14\uD0D5",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for CDN_HAMCHOB_R",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uC0C8\uBC14\uD0D5",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "\uC0C8\uBC14\uD0D5"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uC0C8\uBC14\uD0D5",
                "\uD55C\uCEF4\uBC14\uD0D5",
                "\uD568\uCD08\uB86C\uBC14\uD0D5",
                "\uD568\uCD08\uB871\uBC14\uD0D5"
              ],
              "url": "https://cdn.jsdelivr.net/gh/projectnoonnu/noonfonts_2104@1.0/HANBatang.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.30078d3a0db57db6e3a4.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "HY\uD5E4\uB4DC\uB77C\uC778M",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/NotoSansKR-Bold.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "HY\uD5E4\uB4DC\uB77C\uC778M",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uC591\uC7AC\uD2BC\uD2BC\uCCB4B",
                "HY\uACAC\uACE0\uB515",
                "HY\uD5E4\uB4DC\uB77C\uC778M",
                "HYGothic-Extra",
                "HYHeadLine M",
                "HYHeadLine Medium"
              ],
              "url": "fonts/NotoSansKR-Bold.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uC591\uC7AC\uD2BC\uD2BC\uCCB4B",
                "HY\uACAC\uACE0\uB515",
                "HY\uD5E4\uB4DC\uB77C\uC778M",
                "HYGothic-Extra",
                "HYHeadLine M",
                "HYHeadLine Medium"
              ],
              "url": "fonts/NotoSansKR-Bold.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.62f82c6c6e42b2466712.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "HYHeadLine M",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/NotoSansKR-Bold.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "HYHeadLine M",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uC591\uC7AC\uD2BC\uD2BC\uCCB4B",
                "HY\uACAC\uACE0\uB515",
                "HY\uD5E4\uB4DC\uB77C\uC778M",
                "HYGothic-Extra",
                "HYHeadLine M",
                "HYHeadLine Medium"
              ],
              "url": "fonts/NotoSansKR-Bold.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uC591\uC7AC\uD2BC\uD2BC\uCCB4B",
                "HY\uACAC\uACE0\uB515",
                "HY\uD5E4\uB4DC\uB77C\uC778M",
                "HYGothic-Extra",
                "HYHeadLine M",
                "HYHeadLine Medium"
              ],
              "url": "fonts/NotoSansKR-Bold.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.e5f20e53cc00a1c7dfd1.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "HYHeadLine Medium",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/NotoSansKR-Bold.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "HYHeadLine Medium",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uC591\uC7AC\uD2BC\uD2BC\uCCB4B",
                "HY\uACAC\uACE0\uB515",
                "HY\uD5E4\uB4DC\uB77C\uC778M",
                "HYGothic-Extra",
                "HYHeadLine M",
                "HYHeadLine Medium"
              ],
              "url": "fonts/NotoSansKR-Bold.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uC591\uC7AC\uD2BC\uD2BC\uCCB4B",
                "HY\uACAC\uACE0\uB515",
                "HY\uD5E4\uB4DC\uB77C\uC778M",
                "HYGothic-Extra",
                "HYHeadLine M",
                "HYHeadLine Medium"
              ],
              "url": "fonts/NotoSansKR-Bold.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.86f800aa66064bb9adaf.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "HY\uACAC\uACE0\uB515",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/NotoSansKR-Bold.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "HY\uACAC\uACE0\uB515",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uC591\uC7AC\uD2BC\uD2BC\uCCB4B",
                "HY\uACAC\uACE0\uB515",
                "HY\uD5E4\uB4DC\uB77C\uC778M",
                "HYGothic-Extra",
                "HYHeadLine M",
                "HYHeadLine Medium"
              ],
              "url": "fonts/NotoSansKR-Bold.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uC591\uC7AC\uD2BC\uD2BC\uCCB4B",
                "HY\uACAC\uACE0\uB515",
                "HY\uD5E4\uB4DC\uB77C\uC778M",
                "HYGothic-Extra",
                "HYHeadLine M",
                "HYHeadLine Medium"
              ],
              "url": "fonts/NotoSansKR-Bold.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.0cfefc4a25911abc7b28.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "HYGothic-Extra",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/NotoSansKR-Bold.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "HYGothic-Extra",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uC591\uC7AC\uD2BC\uD2BC\uCCB4B",
                "HY\uACAC\uACE0\uB515",
                "HY\uD5E4\uB4DC\uB77C\uC778M",
                "HYGothic-Extra",
                "HYHeadLine M",
                "HYHeadLine Medium"
              ],
              "url": "fonts/NotoSansKR-Bold.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uC591\uC7AC\uD2BC\uD2BC\uCCB4B",
                "HY\uACAC\uACE0\uB515",
                "HY\uD5E4\uB4DC\uB77C\uC778M",
                "HYGothic-Extra",
                "HYHeadLine M",
                "HYHeadLine Medium"
              ],
              "url": "fonts/NotoSansKR-Bold.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.94a8953162d2d51c96ba.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "HY\uADF8\uB798\uD53D",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/NotoSansKR-Regular.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "HY\uADF8\uB798\uD53D",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uD55C\uC591\uC911\uACE0\uB515",
                "HY\uADF8\uB798\uD53D",
                "HY\uADF8\uB798\uD53DM",
                "HY\uC911\uACE0\uB515",
                "HYGraphic-Medium",
                "Noto Sans KR"
              ],
              "url": "fonts/NotoSansKR-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uD55C\uC591\uC911\uACE0\uB515",
                "HY\uADF8\uB798\uD53D",
                "HY\uADF8\uB798\uD53DM",
                "HY\uC911\uACE0\uB515",
                "HYGraphic-Medium",
                "Noto Sans KR"
              ],
              "url": "fonts/NotoSansKR-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.88a1eb20cd3b549115cb.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "HYGraphic-Medium",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/NotoSansKR-Regular.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "HYGraphic-Medium",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uD55C\uC591\uC911\uACE0\uB515",
                "HY\uADF8\uB798\uD53D",
                "HY\uADF8\uB798\uD53DM",
                "HY\uC911\uACE0\uB515",
                "HYGraphic-Medium",
                "Noto Sans KR"
              ],
              "url": "fonts/NotoSansKR-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uD55C\uC591\uC911\uACE0\uB515",
                "HY\uADF8\uB798\uD53D",
                "HY\uADF8\uB798\uD53DM",
                "HY\uC911\uACE0\uB515",
                "HYGraphic-Medium",
                "Noto Sans KR"
              ],
              "url": "fonts/NotoSansKR-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.3753c27802a6697adaca.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "HY\uADF8\uB798\uD53DM",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/NotoSansKR-Regular.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "HY\uADF8\uB798\uD53DM",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uD55C\uC591\uC911\uACE0\uB515",
                "HY\uADF8\uB798\uD53D",
                "HY\uADF8\uB798\uD53DM",
                "HY\uC911\uACE0\uB515",
                "HYGraphic-Medium",
                "Noto Sans KR"
              ],
              "url": "fonts/NotoSansKR-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uD55C\uC591\uC911\uACE0\uB515",
                "HY\uADF8\uB798\uD53D",
                "HY\uADF8\uB798\uD53DM",
                "HY\uC911\uACE0\uB515",
                "HYGraphic-Medium",
                "Noto Sans KR"
              ],
              "url": "fonts/NotoSansKR-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.29d6d127a0d52037a7a5.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "HY\uACAC\uBA85\uC870",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/NotoSerifKR-Bold.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "HY\uACAC\uBA85\uC870",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "HY\uACAC\uBA85\uC870",
                "HYMyeongJo-Extra"
              ],
              "url": "fonts/NotoSerifKR-Bold.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "HY\uACAC\uBA85\uC870",
                "HYMyeongJo-Extra"
              ],
              "url": "fonts/NotoSerifKR-Bold.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.833df2e422075c8bd815.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "HYMyeongJo-Extra",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/NotoSerifKR-Bold.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "HYMyeongJo-Extra",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "HY\uACAC\uBA85\uC870",
                "HYMyeongJo-Extra"
              ],
              "url": "fonts/NotoSerifKR-Bold.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "HY\uACAC\uBA85\uC870",
                "HYMyeongJo-Extra"
              ],
              "url": "fonts/NotoSerifKR-Bold.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.93eb9ff639f4cfcfb962.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "HY\uC2E0\uBA85\uC870",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/NotoSerifKR-Regular.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "HY\uC2E0\uBA85\uC870",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uBC14\uD0D5",
                "HY\uC2E0\uBA85\uC870",
                "Noto Serif KR",
                "Palatino Linotype"
              ],
              "url": "fonts/NotoSerifKR-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uBC14\uD0D5",
                "HY\uC2E0\uBA85\uC870",
                "Noto Serif KR",
                "Palatino Linotype"
              ],
              "url": "fonts/NotoSerifKR-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.a34b73718b0ffd09a21b.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "HY\uC911\uACE0\uB515",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/NotoSansKR-Regular.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "HY\uC911\uACE0\uB515",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uD55C\uC591\uC911\uACE0\uB515",
                "HY\uADF8\uB798\uD53D",
                "HY\uADF8\uB798\uD53DM",
                "HY\uC911\uACE0\uB515",
                "HYGraphic-Medium",
                "Noto Sans KR"
              ],
              "url": "fonts/NotoSansKR-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uD55C\uC591\uC911\uACE0\uB515",
                "HY\uADF8\uB798\uD53D",
                "HY\uADF8\uB798\uD53DM",
                "HY\uC911\uACE0\uB515",
                "HYGraphic-Medium",
                "Noto Sans KR"
              ],
              "url": "fonts/NotoSansKR-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.856cdf2bb6bf547fb7da.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uD55C\uC591\uC911\uACE0\uB515",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/NotoSansKR-Regular.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uD55C\uC591\uC911\uACE0\uB515",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uD55C\uC591\uC911\uACE0\uB515",
                "HY\uADF8\uB798\uD53D",
                "HY\uADF8\uB798\uD53DM",
                "HY\uC911\uACE0\uB515",
                "HYGraphic-Medium",
                "Noto Sans KR"
              ],
              "url": "fonts/NotoSansKR-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uD55C\uC591\uC911\uACE0\uB515",
                "HY\uADF8\uB798\uD53D",
                "HY\uADF8\uB798\uD53DM",
                "HY\uC911\uACE0\uB515",
                "HYGraphic-Medium",
                "Noto Sans KR"
              ],
              "url": "fonts/NotoSansKR-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.3ba7f1f7809a833b969a.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uC591\uC7AC\uD2BC\uD2BC\uCCB4B",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/NotoSansKR-Bold.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uC591\uC7AC\uD2BC\uD2BC\uCCB4B",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uC591\uC7AC\uD2BC\uD2BC\uCCB4B",
                "HY\uACAC\uACE0\uB515",
                "HY\uD5E4\uB4DC\uB77C\uC778M",
                "HYGothic-Extra",
                "HYHeadLine M",
                "HYHeadLine Medium"
              ],
              "url": "fonts/NotoSansKR-Bold.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uC591\uC7AC\uD2BC\uD2BC\uCCB4B",
                "HY\uACAC\uACE0\uB515",
                "HY\uD5E4\uB4DC\uB77C\uC778M",
                "HYGothic-Extra",
                "HYHeadLine M",
                "HYHeadLine Medium"
              ],
              "url": "fonts/NotoSansKR-Bold.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.d988ac8884c2a8beab41.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Malgun Gothic",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/Pretendard-Regular.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Malgun Gothic",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uB9D1\uC740 \uACE0\uB515",
                "Malgun Gothic",
                "Pretendard"
              ],
              "url": "fonts/Pretendard-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uB9D1\uC740 \uACE0\uB515",
                "Malgun Gothic",
                "Pretendard"
              ],
              "url": "fonts/Pretendard-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.b247488092a350760c80.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB9D1\uC740 \uACE0\uB515",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/Pretendard-Regular.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uB9D1\uC740 \uACE0\uB515",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uB9D1\uC740 \uACE0\uB515",
                "Malgun Gothic",
                "Pretendard"
              ],
              "url": "fonts/Pretendard-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uB9D1\uC740 \uACE0\uB515",
                "Malgun Gothic",
                "Pretendard"
              ],
              "url": "fonts/Pretendard-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.f09587c087bbefe58254.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB3CB\uC6C0",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/NotoSansKR-ExtraLight.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uB3CB\uC6C0",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uAD74\uB9BC",
                "\uB3CB\uC6C0",
                "\uB3CB\uC6C0\uCCB4",
                "\uC0C8\uAD74\uB9BC",
                "Haansoft Dotum",
                "Noto Sans KR ExtraLight"
              ],
              "url": "fonts/NotoSansKR-ExtraLight.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uAD74\uB9BC",
                "\uB3CB\uC6C0",
                "\uB3CB\uC6C0\uCCB4",
                "\uC0C8\uAD74\uB9BC",
                "Haansoft Dotum",
                "Noto Sans KR ExtraLight"
              ],
              "url": "fonts/NotoSansKR-ExtraLight.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.0448add22607e6fabd3d.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB3CB\uC6C0\uCCB4",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/NotoSansKR-ExtraLight.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uB3CB\uC6C0\uCCB4",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uAD74\uB9BC",
                "\uB3CB\uC6C0",
                "\uB3CB\uC6C0\uCCB4",
                "\uC0C8\uAD74\uB9BC",
                "Haansoft Dotum",
                "Noto Sans KR ExtraLight"
              ],
              "url": "fonts/NotoSansKR-ExtraLight.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uAD74\uB9BC",
                "\uB3CB\uC6C0",
                "\uB3CB\uC6C0\uCCB4",
                "\uC0C8\uAD74\uB9BC",
                "Haansoft Dotum",
                "Noto Sans KR ExtraLight"
              ],
              "url": "fonts/NotoSansKR-ExtraLight.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.26197494604ee7285153.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uAD74\uB9BC",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/NotoSansKR-ExtraLight.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uAD74\uB9BC",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uAD74\uB9BC",
                "\uB3CB\uC6C0",
                "\uB3CB\uC6C0\uCCB4",
                "\uC0C8\uAD74\uB9BC",
                "Haansoft Dotum",
                "Noto Sans KR ExtraLight"
              ],
              "url": "fonts/NotoSansKR-ExtraLight.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uAD74\uB9BC",
                "\uB3CB\uC6C0",
                "\uB3CB\uC6C0\uCCB4",
                "\uC0C8\uAD74\uB9BC",
                "Haansoft Dotum",
                "Noto Sans KR ExtraLight"
              ],
              "url": "fonts/NotoSansKR-ExtraLight.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.4a2e12a75c84cb081aab.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uAD74\uB9BC\uCCB4",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/D2Coding-Regular.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uAD74\uB9BC\uCCB4",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uAD74\uB9BC\uCCB4",
                "\uBC14\uD0D5\uCCB4",
                "D2Coding"
              ],
              "url": "fonts/D2Coding-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uAD74\uB9BC\uCCB4",
                "\uBC14\uD0D5\uCCB4",
                "D2Coding"
              ],
              "url": "fonts/D2Coding-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.ec72133ef5cf9fd282fb.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uC0C8\uAD74\uB9BC",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/NotoSansKR-ExtraLight.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uC0C8\uAD74\uB9BC",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uAD74\uB9BC",
                "\uB3CB\uC6C0",
                "\uB3CB\uC6C0\uCCB4",
                "\uC0C8\uAD74\uB9BC",
                "Haansoft Dotum",
                "Noto Sans KR ExtraLight"
              ],
              "url": "fonts/NotoSansKR-ExtraLight.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uAD74\uB9BC",
                "\uB3CB\uC6C0",
                "\uB3CB\uC6C0\uCCB4",
                "\uC0C8\uAD74\uB9BC",
                "Haansoft Dotum",
                "Noto Sans KR ExtraLight"
              ],
              "url": "fonts/NotoSansKR-ExtraLight.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.411ce3616959e647602c.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Haansoft Dotum",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/NotoSansKR-ExtraLight.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Haansoft Dotum",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uAD74\uB9BC",
                "\uB3CB\uC6C0",
                "\uB3CB\uC6C0\uCCB4",
                "\uC0C8\uAD74\uB9BC",
                "Haansoft Dotum",
                "Noto Sans KR ExtraLight"
              ],
              "url": "fonts/NotoSansKR-ExtraLight.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uAD74\uB9BC",
                "\uB3CB\uC6C0",
                "\uB3CB\uC6C0\uCCB4",
                "\uC0C8\uAD74\uB9BC",
                "Haansoft Dotum",
                "Noto Sans KR ExtraLight"
              ],
              "url": "fonts/NotoSansKR-ExtraLight.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.c7917f3a4fa439763a33.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uBC14\uD0D5",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/NotoSerifKR-Regular.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uBC14\uD0D5",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uBC14\uD0D5",
                "HY\uC2E0\uBA85\uC870",
                "Noto Serif KR",
                "Palatino Linotype"
              ],
              "url": "fonts/NotoSerifKR-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uBC14\uD0D5",
                "HY\uC2E0\uBA85\uC870",
                "Noto Serif KR",
                "Palatino Linotype"
              ],
              "url": "fonts/NotoSerifKR-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.2f05addbdfe5f66a5bd0.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uBC14\uD0D5\uCCB4",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/D2Coding-Regular.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uBC14\uD0D5\uCCB4",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uAD74\uB9BC\uCCB4",
                "\uBC14\uD0D5\uCCB4",
                "D2Coding"
              ],
              "url": "fonts/D2Coding-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uAD74\uB9BC\uCCB4",
                "\uBC14\uD0D5\uCCB4",
                "D2Coding"
              ],
              "url": "fonts/D2Coding-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.1935f03ba4e1a1890c90.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uAD81\uC11C",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/GowunBatang-Regular.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uAD81\uC11C",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uACE0\uC6B4\uBC14\uD0D5",
                "\uAD81\uC11C",
                "\uAD81\uC11C\uCCB4",
                "\uC0C8\uAD81\uC11C"
              ],
              "url": "fonts/GowunBatang-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uACE0\uC6B4\uBC14\uD0D5",
                "\uAD81\uC11C",
                "\uAD81\uC11C\uCCB4",
                "\uC0C8\uAD81\uC11C"
              ],
              "url": "fonts/GowunBatang-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.85a2d17c39656a68a057.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uAD81\uC11C\uCCB4",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/GowunBatang-Regular.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uAD81\uC11C\uCCB4",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uACE0\uC6B4\uBC14\uD0D5",
                "\uAD81\uC11C",
                "\uAD81\uC11C\uCCB4",
                "\uC0C8\uAD81\uC11C"
              ],
              "url": "fonts/GowunBatang-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uACE0\uC6B4\uBC14\uD0D5",
                "\uAD81\uC11C",
                "\uAD81\uC11C\uCCB4",
                "\uC0C8\uAD81\uC11C"
              ],
              "url": "fonts/GowunBatang-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.1cb50440148d64980dac.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uC0C8\uAD81\uC11C",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/GowunBatang-Regular.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uC0C8\uAD81\uC11C",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uACE0\uC6B4\uBC14\uD0D5",
                "\uAD81\uC11C",
                "\uAD81\uC11C\uCCB4",
                "\uC0C8\uAD81\uC11C"
              ],
              "url": "fonts/GowunBatang-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uACE0\uC6B4\uBC14\uD0D5",
                "\uAD81\uC11C",
                "\uAD81\uC11C\uCCB4",
                "\uC0C8\uAD81\uC11C"
              ],
              "url": "fonts/GowunBatang-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.600e8918afb7dce374f4.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB098\uB214\uACE0\uB515",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/NanumGothic-Regular.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uB098\uB214\uACE0\uB515",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uB098\uB214\uACE0\uB515",
                "NanumGothic"
              ],
              "url": "fonts/NanumGothic-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uB098\uB214\uACE0\uB515",
                "NanumGothic"
              ],
              "url": "fonts/NanumGothic-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.3036d5d8cc5c14a890c9.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB098\uB214\uACE0\uB515 Bold",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for CDN_NANUM_GOTHIC_BOLD",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uB098\uB214\uACE0\uB515 Bold",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "\uB098\uB214\uACE0\uB515 Bold"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uB098\uB214\uACE0\uB515 Bold"
              ],
              "url": "https://cdn.jsdelivr.net/npm/@fontsource/nanum-gothic@5.3.0/files/nanum-gothic-0-700-normal.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.bddb33f3dad691a36c3e.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB098\uB214\uACE0\uB515 ExtraBold",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for CDN_NANUM_GOTHIC_EXTRA_BOLD",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uB098\uB214\uACE0\uB515 ExtraBold",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "\uB098\uB214\uACE0\uB515 ExtraBold"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uB098\uB214\uACE0\uB515 ExtraBold"
              ],
              "url": "https://cdn.jsdelivr.net/npm/@fontsource/nanum-gothic@5.3.0/files/nanum-gothic-0-800-normal.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.9dacb9d11f184d63edb3.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB098\uB214\uBA85\uC870",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/NanumMyeongjo-Regular.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uB098\uB214\uBA85\uC870",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uB098\uB214\uBA85\uC870"
              ],
              "url": "fonts/NanumMyeongjo-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uB098\uB214\uBA85\uC870"
              ],
              "url": "fonts/NanumMyeongjo-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.d08686d681c97e128496.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB098\uB214\uBA85\uC870 ExtraBold",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for CDN_NANUM_MYEONGJO_EXTRA_BOLD",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uB098\uB214\uBA85\uC870 ExtraBold",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "\uB098\uB214\uBA85\uC870 ExtraBold"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uB098\uB214\uBA85\uC870 ExtraBold"
              ],
              "url": "https://cdn.jsdelivr.net/npm/@fontsource/nanum-myeongjo@5.3.0/files/nanum-myeongjo-0-800-normal.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.a85bd10cee9ebd997eee.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB098\uB214\uACE0\uB515\uCF54\uB529",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/NanumGothicCoding-Regular.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uB098\uB214\uACE0\uB515\uCF54\uB529",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uB098\uB214\uACE0\uB515_\uCF54\uB529",
                "\uB098\uB214\uACE0\uB515\uCF54\uB529"
              ],
              "url": "fonts/NanumGothicCoding-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uB098\uB214\uACE0\uB515_\uCF54\uB529",
                "\uB098\uB214\uACE0\uB515\uCF54\uB529"
              ],
              "url": "fonts/NanumGothicCoding-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.dd065bb47aec6ca6723d.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB098\uB214\uACE0\uB515_\uCF54\uB529",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/NanumGothicCoding-Regular.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uB098\uB214\uACE0\uB515_\uCF54\uB529",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uB098\uB214\uACE0\uB515_\uCF54\uB529",
                "\uB098\uB214\uACE0\uB515\uCF54\uB529"
              ],
              "url": "fonts/NanumGothicCoding-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uB098\uB214\uACE0\uB515_\uCF54\uB529",
                "\uB098\uB214\uACE0\uB515\uCF54\uB529"
              ],
              "url": "fonts/NanumGothicCoding-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.223d8475001285897db8.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "NanumGothic",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/NanumGothic-Regular.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "NanumGothic",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uB098\uB214\uACE0\uB515",
                "NanumGothic"
              ],
              "url": "fonts/NanumGothic-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uB098\uB214\uACE0\uB515",
                "NanumGothic"
              ],
              "url": "fonts/NanumGothic-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.86194ca892a082c950b8.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Palatino Linotype",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/NotoSerifKR-Regular.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Palatino Linotype",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uBC14\uD0D5",
                "HY\uC2E0\uBA85\uC870",
                "Noto Serif KR",
                "Palatino Linotype"
              ],
              "url": "fonts/NotoSerifKR-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uBC14\uD0D5",
                "HY\uC2E0\uBA85\uC870",
                "Noto Serif KR",
                "Palatino Linotype"
              ],
              "url": "fonts/NotoSerifKR-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.8175c2ae512fdcecc704.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Noto Sans KR",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/NotoSansKR-Regular.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Noto Sans KR",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uD55C\uC591\uC911\uACE0\uB515",
                "HY\uADF8\uB798\uD53D",
                "HY\uADF8\uB798\uD53DM",
                "HY\uC911\uACE0\uB515",
                "HYGraphic-Medium",
                "Noto Sans KR"
              ],
              "url": "fonts/NotoSansKR-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uD55C\uC591\uC911\uACE0\uB515",
                "HY\uADF8\uB798\uD53D",
                "HY\uADF8\uB798\uD53DM",
                "HY\uC911\uACE0\uB515",
                "HYGraphic-Medium",
                "Noto Sans KR"
              ],
              "url": "fonts/NotoSansKR-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.d8acdee5efab4ff80ae7.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Noto Sans KR Medium",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for CDN_NOTO_SANS_KR_MEDIUM",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Noto Sans KR Medium",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "Noto Sans KR Medium"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "Noto Sans KR Medium"
              ],
              "url": "https://cdn.jsdelivr.net/npm/@fontsource/noto-sans-kr@5.3.0/files/noto-sans-kr-0-500-normal.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.370ab90396cbd2cefa67.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Noto Sans KR ExtraLight",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/NotoSansKR-ExtraLight.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Noto Sans KR ExtraLight",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uAD74\uB9BC",
                "\uB3CB\uC6C0",
                "\uB3CB\uC6C0\uCCB4",
                "\uC0C8\uAD74\uB9BC",
                "Haansoft Dotum",
                "Noto Sans KR ExtraLight"
              ],
              "url": "fonts/NotoSansKR-ExtraLight.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uAD74\uB9BC",
                "\uB3CB\uC6C0",
                "\uB3CB\uC6C0\uCCB4",
                "\uC0C8\uAD74\uB9BC",
                "Haansoft Dotum",
                "Noto Sans KR ExtraLight"
              ],
              "url": "fonts/NotoSansKR-ExtraLight.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.16a7ab9887c570ec0d99.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Noto Serif KR",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/NotoSerifKR-Regular.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Noto Serif KR",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uBC14\uD0D5",
                "HY\uC2E0\uBA85\uC870",
                "Noto Serif KR",
                "Palatino Linotype"
              ],
              "url": "fonts/NotoSerifKR-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uBC14\uD0D5",
                "HY\uC2E0\uBA85\uC870",
                "Noto Serif KR",
                "Palatino Linotype"
              ],
              "url": "fonts/NotoSerifKR-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.746b8c3993b4f81def2c.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Pretendard",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/Pretendard-Regular.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Pretendard",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uB9D1\uC740 \uACE0\uB515",
                "Malgun Gothic",
                "Pretendard"
              ],
              "url": "fonts/Pretendard-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uB9D1\uC740 \uACE0\uB515",
                "Malgun Gothic",
                "Pretendard"
              ],
              "url": "fonts/Pretendard-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.be1e50dc2beb3d0f60e3.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Pretendard Thin",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/Pretendard-Thin.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Pretendard Thin",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "Pretendard Thin"
              ],
              "url": "fonts/Pretendard-Thin.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "Pretendard Thin"
              ],
              "url": "fonts/Pretendard-Thin.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.afd86ce934ac67467a43.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Pretendard ExtraLight",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/Pretendard-ExtraLight.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Pretendard ExtraLight",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "Pretendard ExtraLight"
              ],
              "url": "fonts/Pretendard-ExtraLight.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "Pretendard ExtraLight"
              ],
              "url": "fonts/Pretendard-ExtraLight.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.2121cbb9a8a2c4566a4c.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Pretendard Light",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/Pretendard-Light.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Pretendard Light",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "Pretendard Light"
              ],
              "url": "fonts/Pretendard-Light.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "Pretendard Light"
              ],
              "url": "fonts/Pretendard-Light.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.37b271c9e695ce40a5c7.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Pretendard Medium",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/Pretendard-Medium.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Pretendard Medium",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "Pretendard Medium"
              ],
              "url": "fonts/Pretendard-Medium.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "Pretendard Medium"
              ],
              "url": "fonts/Pretendard-Medium.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.e9989f499770a1829563.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Pretendard SemiBold",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/Pretendard-SemiBold.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Pretendard SemiBold",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "Pretendard SemiBold"
              ],
              "url": "fonts/Pretendard-SemiBold.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "Pretendard SemiBold"
              ],
              "url": "fonts/Pretendard-SemiBold.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.30364eaa2fa741fabe4c.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Pretendard Bold",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/Pretendard-Bold.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Pretendard Bold",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "Pretendard Bold"
              ],
              "url": "fonts/Pretendard-Bold.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "Pretendard Bold"
              ],
              "url": "fonts/Pretendard-Bold.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.87d8b2801087e772ddb3.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Pretendard ExtraBold",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/Pretendard-ExtraBold.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Pretendard ExtraBold",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "Pretendard ExtraBold"
              ],
              "url": "fonts/Pretendard-ExtraBold.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "Pretendard ExtraBold"
              ],
              "url": "fonts/Pretendard-ExtraBold.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.eef87dc1aae34a7afc2c.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Pretendard Black",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/Pretendard-Black.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Pretendard Black",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "Pretendard Black"
              ],
              "url": "fonts/Pretendard-Black.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "Pretendard Black"
              ],
              "url": "fonts/Pretendard-Black.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.5e648d7aa6c2db3be53d.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "DejaVu Serif",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for CDN_DEJAVU_SERIF_REGULAR",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "DejaVu Serif",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "DejaVu Serif"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "DejaVu Serif"
              ],
              "url": "https://cdn.jsdelivr.net/npm/@fontsource/dejavu-serif@5.3.0/files/dejavu-serif-latin-400-normal.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.45ef6b86328af59f834c.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Roboto",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for CDN_ROBOTO_REGULAR",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Roboto",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "Roboto"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "Roboto"
              ],
              "url": "https://cdn.jsdelivr.net/npm/@fontsource/roboto@5.3.0/files/roboto-latin-400-normal.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.9226454d982d47a1557d.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Government_16040911",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for CDN_GOVERNMENT_SYMBOL_REGULAR",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Government_16040911",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "Government_16040911"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uC815\uBD80\uC0C1\uC9D5 \uBD80\uCC98\uBA85_16040911",
                "Government_16040911"
              ],
              "url": "https://cdn.jsdelivr.net/gh/jangster77/korea-government-symbol-font@v1.0.0/fonts/Government_16040911.ttf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.521afff37dd1f6357469.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uC815\uBD80\uC0C1\uC9D5 \uBD80\uCC98\uBA85_16040911",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for CDN_GOVERNMENT_SYMBOL_REGULAR",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uC815\uBD80\uC0C1\uC9D5 \uBD80\uCC98\uBA85_16040911",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "\uC815\uBD80\uC0C1\uC9D5 \uBD80\uCC98\uBA85_16040911"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uC815\uBD80\uC0C1\uC9D5 \uBD80\uCC98\uBA85_16040911",
                "Government_16040911"
              ],
              "url": "https://cdn.jsdelivr.net/gh/jangster77/korea-government-symbol-font@v1.0.0/fonts/Government_16040911.ttf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.f718d270a6f25396c4af.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPub\uB3CB\uC6C0\uCCB4 Light",
      "targetFaceOrPolicy": "`${CDN_KOPUB}/KoPubDotum-Light.ttf`",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": true,
        "declaredCapability": "sfnt-source",
        "fontFamily": "KoPub\uB3CB\uC6C0\uCCB4 Light",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "KoPub\uB3CB\uC6C0\uCCB4 Light"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "KoPub\uB3CB\uC6C0\uCCB4 Light",
                "KoPubDotum Light",
                "KoPubDotumLight"
              ],
              "url": "https://cdn.jsdelivr.net/npm/font-kopub@1.0.2/fonts/KoPubDotum-Light.ttf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.a93f39ddc1e2f413d204.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPub\uB3CB\uC6C0\uCCB4 Medium",
      "targetFaceOrPolicy": "`${CDN_KOPUB}/KoPubDotum-Medium.ttf`",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": true,
        "declaredCapability": "sfnt-source",
        "fontFamily": "KoPub\uB3CB\uC6C0\uCCB4 Medium",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "KoPub\uB3CB\uC6C0\uCCB4 Medium"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "KoPub\uB3CB\uC6C0\uCCB4 Medium",
                "KoPubDotum Medium",
                "KoPubDotumMedium"
              ],
              "url": "https://cdn.jsdelivr.net/npm/font-kopub@1.0.2/fonts/KoPubDotum-Medium.ttf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.3f2ebfb25f1e24a5e022.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPub\uB3CB\uC6C0\uCCB4 Bold",
      "targetFaceOrPolicy": "`${CDN_KOPUB}/KoPubDotum-Bold.ttf`",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": true,
        "declaredCapability": "sfnt-source",
        "fontFamily": "KoPub\uB3CB\uC6C0\uCCB4 Bold",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "KoPub\uB3CB\uC6C0\uCCB4 Bold"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "KoPub\uB3CB\uC6C0\uCCB4 Bold",
                "KoPubDotum Bold",
                "KoPubDotumBold"
              ],
              "url": "https://cdn.jsdelivr.net/npm/font-kopub@1.0.2/fonts/KoPubDotum-Bold.ttf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.bb3cbc04a878dd35803c.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPub\uBC14\uD0D5\uCCB4 Light",
      "targetFaceOrPolicy": "`${CDN_KOPUB}/KoPubBatang-Light.ttf`",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": true,
        "declaredCapability": "sfnt-source",
        "fontFamily": "KoPub\uBC14\uD0D5\uCCB4 Light",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "KoPub\uBC14\uD0D5\uCCB4 Light"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "KoPub\uBC14\uD0D5\uCCB4 Light",
                "KoPubBatang Light",
                "KoPubBatangLight"
              ],
              "url": "https://cdn.jsdelivr.net/npm/font-kopub@1.0.2/fonts/KoPubBatang-Light.ttf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.c376561582c767a780fd.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPub\uBC14\uD0D5\uCCB4 Medium",
      "targetFaceOrPolicy": "`${CDN_KOPUB}/KoPubBatang-Medium.ttf`",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": true,
        "declaredCapability": "sfnt-source",
        "fontFamily": "KoPub\uBC14\uD0D5\uCCB4 Medium",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "KoPub\uBC14\uD0D5\uCCB4 Medium"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "KoPub\uBC14\uD0D5\uCCB4 Medium",
                "KoPubBatang Medium",
                "KoPubBatangMedium"
              ],
              "url": "https://cdn.jsdelivr.net/npm/font-kopub@1.0.2/fonts/KoPubBatang-Medium.ttf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.898ab998fcc897199dbf.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPub\uBC14\uD0D5\uCCB4 Bold",
      "targetFaceOrPolicy": "`${CDN_KOPUB}/KoPubBatang-Bold.ttf`",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": true,
        "declaredCapability": "sfnt-source",
        "fontFamily": "KoPub\uBC14\uD0D5\uCCB4 Bold",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "KoPub\uBC14\uD0D5\uCCB4 Bold"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "KoPub\uBC14\uD0D5\uCCB4 Bold",
                "KoPubBatang Bold",
                "KoPubBatangBold"
              ],
              "url": "https://cdn.jsdelivr.net/npm/font-kopub@1.0.2/fonts/KoPubBatang-Bold.ttf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.73bb35832c85fdcfa94a.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubDotum Light",
      "targetFaceOrPolicy": "`${CDN_KOPUB}/KoPubDotum-Light.ttf`",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": true,
        "declaredCapability": "sfnt-source",
        "fontFamily": "KoPubDotum Light",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "KoPubDotum Light"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "KoPub\uB3CB\uC6C0\uCCB4 Light",
                "KoPubDotum Light",
                "KoPubDotumLight"
              ],
              "url": "https://cdn.jsdelivr.net/npm/font-kopub@1.0.2/fonts/KoPubDotum-Light.ttf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.334218b855ae9b9950b4.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubDotum Medium",
      "targetFaceOrPolicy": "`${CDN_KOPUB}/KoPubDotum-Medium.ttf`",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": true,
        "declaredCapability": "sfnt-source",
        "fontFamily": "KoPubDotum Medium",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "KoPubDotum Medium"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "KoPub\uB3CB\uC6C0\uCCB4 Medium",
                "KoPubDotum Medium",
                "KoPubDotumMedium"
              ],
              "url": "https://cdn.jsdelivr.net/npm/font-kopub@1.0.2/fonts/KoPubDotum-Medium.ttf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.132bd3983f2110e463bc.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubDotum Bold",
      "targetFaceOrPolicy": "`${CDN_KOPUB}/KoPubDotum-Bold.ttf`",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": true,
        "declaredCapability": "sfnt-source",
        "fontFamily": "KoPubDotum Bold",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "KoPubDotum Bold"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "KoPub\uB3CB\uC6C0\uCCB4 Bold",
                "KoPubDotum Bold",
                "KoPubDotumBold"
              ],
              "url": "https://cdn.jsdelivr.net/npm/font-kopub@1.0.2/fonts/KoPubDotum-Bold.ttf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.8225cfd32925b5ad4dff.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubBatang Light",
      "targetFaceOrPolicy": "`${CDN_KOPUB}/KoPubBatang-Light.ttf`",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": true,
        "declaredCapability": "sfnt-source",
        "fontFamily": "KoPubBatang Light",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "KoPubBatang Light"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "KoPub\uBC14\uD0D5\uCCB4 Light",
                "KoPubBatang Light",
                "KoPubBatangLight"
              ],
              "url": "https://cdn.jsdelivr.net/npm/font-kopub@1.0.2/fonts/KoPubBatang-Light.ttf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.e2bab0aa777f7c235f74.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubBatang Medium",
      "targetFaceOrPolicy": "`${CDN_KOPUB}/KoPubBatang-Medium.ttf`",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": true,
        "declaredCapability": "sfnt-source",
        "fontFamily": "KoPubBatang Medium",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "KoPubBatang Medium"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "KoPub\uBC14\uD0D5\uCCB4 Medium",
                "KoPubBatang Medium",
                "KoPubBatangMedium"
              ],
              "url": "https://cdn.jsdelivr.net/npm/font-kopub@1.0.2/fonts/KoPubBatang-Medium.ttf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.af8d0ba95e9447ddf7dc.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubBatang Bold",
      "targetFaceOrPolicy": "`${CDN_KOPUB}/KoPubBatang-Bold.ttf`",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": true,
        "declaredCapability": "sfnt-source",
        "fontFamily": "KoPubBatang Bold",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "KoPubBatang Bold"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "KoPub\uBC14\uD0D5\uCCB4 Bold",
                "KoPubBatang Bold",
                "KoPubBatangBold"
              ],
              "url": "https://cdn.jsdelivr.net/npm/font-kopub@1.0.2/fonts/KoPubBatang-Bold.ttf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.ab5d962141d56102aa59.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubDotumLight",
      "targetFaceOrPolicy": "`${CDN_KOPUB}/KoPubDotum-Light.ttf`",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": true,
        "declaredCapability": "sfnt-source",
        "fontFamily": "KoPubDotumLight",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "KoPubDotumLight"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "KoPub\uB3CB\uC6C0\uCCB4 Light",
                "KoPubDotum Light",
                "KoPubDotumLight"
              ],
              "url": "https://cdn.jsdelivr.net/npm/font-kopub@1.0.2/fonts/KoPubDotum-Light.ttf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.11811dc7b4887de84937.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubDotumMedium",
      "targetFaceOrPolicy": "`${CDN_KOPUB}/KoPubDotum-Medium.ttf`",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": true,
        "declaredCapability": "sfnt-source",
        "fontFamily": "KoPubDotumMedium",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "KoPubDotumMedium"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "KoPub\uB3CB\uC6C0\uCCB4 Medium",
                "KoPubDotum Medium",
                "KoPubDotumMedium"
              ],
              "url": "https://cdn.jsdelivr.net/npm/font-kopub@1.0.2/fonts/KoPubDotum-Medium.ttf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.444dd63f80256eed471d.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubDotumBold",
      "targetFaceOrPolicy": "`${CDN_KOPUB}/KoPubDotum-Bold.ttf`",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": true,
        "declaredCapability": "sfnt-source",
        "fontFamily": "KoPubDotumBold",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "KoPubDotumBold"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "KoPub\uB3CB\uC6C0\uCCB4 Bold",
                "KoPubDotum Bold",
                "KoPubDotumBold"
              ],
              "url": "https://cdn.jsdelivr.net/npm/font-kopub@1.0.2/fonts/KoPubDotum-Bold.ttf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.92f6e5d4c44c53d9171a.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubBatangLight",
      "targetFaceOrPolicy": "`${CDN_KOPUB}/KoPubBatang-Light.ttf`",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": true,
        "declaredCapability": "sfnt-source",
        "fontFamily": "KoPubBatangLight",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "KoPubBatangLight"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "KoPub\uBC14\uD0D5\uCCB4 Light",
                "KoPubBatang Light",
                "KoPubBatangLight"
              ],
              "url": "https://cdn.jsdelivr.net/npm/font-kopub@1.0.2/fonts/KoPubBatang-Light.ttf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.2fe9515d279228acacee.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubBatangMedium",
      "targetFaceOrPolicy": "`${CDN_KOPUB}/KoPubBatang-Medium.ttf`",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": true,
        "declaredCapability": "sfnt-source",
        "fontFamily": "KoPubBatangMedium",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "KoPubBatangMedium"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "KoPub\uBC14\uD0D5\uCCB4 Medium",
                "KoPubBatang Medium",
                "KoPubBatangMedium"
              ],
              "url": "https://cdn.jsdelivr.net/npm/font-kopub@1.0.2/fonts/KoPubBatang-Medium.ttf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.8a53670839d0037b5b6c.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubBatangBold",
      "targetFaceOrPolicy": "`${CDN_KOPUB}/KoPubBatang-Bold.ttf`",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": true,
        "declaredCapability": "sfnt-source",
        "fontFamily": "KoPubBatangBold",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "KoPubBatangBold"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "KoPub\uBC14\uD0D5\uCCB4 Bold",
                "KoPubBatang Bold",
                "KoPubBatangBold"
              ],
              "url": "https://cdn.jsdelivr.net/npm/font-kopub@1.0.2/fonts/KoPubBatang-Bold.ttf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.b4a81472cc52c505ee6d.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubWorld\uB3CB\uC6C0\uCCB4 Light",
      "targetFaceOrPolicy": "`${CDN_KOPUB_WORLD}/KoPubWorld-Dotum-Light.otf`",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": true,
        "declaredCapability": "sfnt-source",
        "fontFamily": "KoPubWorld\uB3CB\uC6C0\uCCB4 Light",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "KoPubWorld\uB3CB\uC6C0\uCCB4 Light"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "KoPubWorld\uB3CB\uC6C0\uCCB4 Light"
              ],
              "url": "https://cdn.jsdelivr.net/npm/font-kopubworld@1.0.3/fonts/KoPubWorld-Dotum-Light.otf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.275188318957f26d8f80.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubWorld\uB3CB\uC6C0\uCCB4 Medium",
      "targetFaceOrPolicy": "`${CDN_KOPUB_WORLD}/KoPubWorld-Dotum-Medium.otf`",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": true,
        "declaredCapability": "sfnt-source",
        "fontFamily": "KoPubWorld\uB3CB\uC6C0\uCCB4 Medium",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "KoPubWorld\uB3CB\uC6C0\uCCB4 Medium"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "KoPubWorld Dotum",
                "KoPubWorld\uB3CB\uC6C0\uCCB4 Medium",
                "KoPubWorldDotum"
              ],
              "url": "https://cdn.jsdelivr.net/npm/font-kopubworld@1.0.3/fonts/KoPubWorld-Dotum-Medium.otf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.1e957b44174bb4e58a05.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubWorld\uB3CB\uC6C0\uCCB4 Bold",
      "targetFaceOrPolicy": "`${CDN_KOPUB_WORLD}/KoPubWorld-Dotum-Bold.otf`",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": true,
        "declaredCapability": "sfnt-source",
        "fontFamily": "KoPubWorld\uB3CB\uC6C0\uCCB4 Bold",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "KoPubWorld\uB3CB\uC6C0\uCCB4 Bold"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "KoPubWorld\uB3CB\uC6C0\uCCB4 Bold"
              ],
              "url": "https://cdn.jsdelivr.net/npm/font-kopubworld@1.0.3/fonts/KoPubWorld-Dotum-Bold.otf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.272f0ba64ebeef347d44.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubWorld\uBC14\uD0D5\uCCB4 Light",
      "targetFaceOrPolicy": "`${CDN_KOPUB_WORLD}/KoPubWorld-Batang-Light.otf`",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": true,
        "declaredCapability": "sfnt-source",
        "fontFamily": "KoPubWorld\uBC14\uD0D5\uCCB4 Light",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "KoPubWorld\uBC14\uD0D5\uCCB4 Light"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "KoPubWorld\uBC14\uD0D5\uCCB4 Light"
              ],
              "url": "https://cdn.jsdelivr.net/npm/font-kopubworld@1.0.3/fonts/KoPubWorld-Batang-Light.otf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.81125e4480d6704cd407.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubWorld\uBC14\uD0D5\uCCB4 Medium",
      "targetFaceOrPolicy": "`${CDN_KOPUB_WORLD}/KoPubWorld-Batang-Medium.otf`",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": true,
        "declaredCapability": "sfnt-source",
        "fontFamily": "KoPubWorld\uBC14\uD0D5\uCCB4 Medium",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "KoPubWorld\uBC14\uD0D5\uCCB4 Medium"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "KoPubWorld Batang",
                "KoPubWorld\uBC14\uD0D5\uCCB4 Medium",
                "KoPubWorldBatang"
              ],
              "url": "https://cdn.jsdelivr.net/npm/font-kopubworld@1.0.3/fonts/KoPubWorld-Batang-Medium.otf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.0c50fe05921a7c299e56.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubWorld\uBC14\uD0D5\uCCB4 Bold",
      "targetFaceOrPolicy": "`${CDN_KOPUB_WORLD}/KoPubWorld-Batang-Bold.otf`",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": true,
        "declaredCapability": "sfnt-source",
        "fontFamily": "KoPubWorld\uBC14\uD0D5\uCCB4 Bold",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "KoPubWorld\uBC14\uD0D5\uCCB4 Bold"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "KoPubWorld\uBC14\uD0D5\uCCB4 Bold"
              ],
              "url": "https://cdn.jsdelivr.net/npm/font-kopubworld@1.0.3/fonts/KoPubWorld-Batang-Bold.otf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.4acaa1b1c7544f6b8ffd.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubWorld Dotum",
      "targetFaceOrPolicy": "`${CDN_KOPUB_WORLD}/KoPubWorld-Dotum-Medium.otf`",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": true,
        "declaredCapability": "sfnt-source",
        "fontFamily": "KoPubWorld Dotum",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "KoPubWorld Dotum"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "KoPubWorld Dotum",
                "KoPubWorld\uB3CB\uC6C0\uCCB4 Medium",
                "KoPubWorldDotum"
              ],
              "url": "https://cdn.jsdelivr.net/npm/font-kopubworld@1.0.3/fonts/KoPubWorld-Dotum-Medium.otf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.675b1aec7f8844bb0897.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubWorld Batang",
      "targetFaceOrPolicy": "`${CDN_KOPUB_WORLD}/KoPubWorld-Batang-Medium.otf`",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": true,
        "declaredCapability": "sfnt-source",
        "fontFamily": "KoPubWorld Batang",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "KoPubWorld Batang"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "KoPubWorld Batang",
                "KoPubWorld\uBC14\uD0D5\uCCB4 Medium",
                "KoPubWorldBatang"
              ],
              "url": "https://cdn.jsdelivr.net/npm/font-kopubworld@1.0.3/fonts/KoPubWorld-Batang-Medium.otf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.bdc440581b1fca926d22.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubWorldDotum",
      "targetFaceOrPolicy": "`${CDN_KOPUB_WORLD}/KoPubWorld-Dotum-Medium.otf`",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": true,
        "declaredCapability": "sfnt-source",
        "fontFamily": "KoPubWorldDotum",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "KoPubWorldDotum"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "KoPubWorld Dotum",
                "KoPubWorld\uB3CB\uC6C0\uCCB4 Medium",
                "KoPubWorldDotum"
              ],
              "url": "https://cdn.jsdelivr.net/npm/font-kopubworld@1.0.3/fonts/KoPubWorld-Dotum-Medium.otf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.32defe91e23de06f16c4.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KoPubWorldBatang",
      "targetFaceOrPolicy": "`${CDN_KOPUB_WORLD}/KoPubWorld-Batang-Medium.otf`",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": true,
        "declaredCapability": "sfnt-source",
        "fontFamily": "KoPubWorldBatang",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "KoPubWorldBatang"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "KoPubWorld Batang",
                "KoPubWorld\uBC14\uD0D5\uCCB4 Medium",
                "KoPubWorldBatang"
              ],
              "url": "https://cdn.jsdelivr.net/npm/font-kopubworld@1.0.3/fonts/KoPubWorld-Batang-Medium.otf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.977ef99cd33d09129a6b.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uACBD\uAE30\uCC9C\uB144\uBC14\uD0D5 Bold",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for `${CDN_GYEONGGI_MILLENNIUM}/Batang_Regular.woff`",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uACBD\uAE30\uCC9C\uB144\uBC14\uD0D5 Bold",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "\uACBD\uAE30\uCC9C\uB144\uBC14\uD0D5 Bold"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uACBD\uAE30\uCC9C\uB144\uBC14\uD0D5 Bold",
                "\uACBD\uAE30\uCC9C\uB144\uBC14\uD0D5 Regular"
              ],
              "url": "https://cdn.jsdelivr.net/gh/projectnoonnu/2410-3@1.0/Batang_Regular.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.2041f33491f87ddee0af.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uACBD\uAE30\uCC9C\uB144\uBC14\uD0D5 Regular",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for `${CDN_GYEONGGI_MILLENNIUM}/Batang_Regular.woff`",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uACBD\uAE30\uCC9C\uB144\uBC14\uD0D5 Regular",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "\uACBD\uAE30\uCC9C\uB144\uBC14\uD0D5 Regular"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uACBD\uAE30\uCC9C\uB144\uBC14\uD0D5 Bold",
                "\uACBD\uAE30\uCC9C\uB144\uBC14\uD0D5 Regular"
              ],
              "url": "https://cdn.jsdelivr.net/gh/projectnoonnu/2410-3@1.0/Batang_Regular.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.f14e188b83ef32e773dd.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uACBD\uAE30\uCC9C\uB144\uC81C\uBAA9 Bold",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for `${CDN_GYEONGGI_MILLENNIUM}/Title_Medium.woff`",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uACBD\uAE30\uCC9C\uB144\uC81C\uBAA9 Bold",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "\uACBD\uAE30\uCC9C\uB144\uC81C\uBAA9 Bold"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uACBD\uAE30\uCC9C\uB144\uC81C\uBAA9 Bold",
                "\uACBD\uAE30\uCC9C\uB144\uC81C\uBAA9 Light",
                "\uACBD\uAE30\uCC9C\uB144\uC81C\uBAA9 Medium"
              ],
              "url": "https://cdn.jsdelivr.net/gh/projectnoonnu/2410-3@1.0/Title_Medium.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.baf9ef5d6088912b069e.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uACBD\uAE30\uCC9C\uB144\uC81C\uBAA9 Light",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for `${CDN_GYEONGGI_MILLENNIUM}/Title_Medium.woff`",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uACBD\uAE30\uCC9C\uB144\uC81C\uBAA9 Light",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "\uACBD\uAE30\uCC9C\uB144\uC81C\uBAA9 Light"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uACBD\uAE30\uCC9C\uB144\uC81C\uBAA9 Bold",
                "\uACBD\uAE30\uCC9C\uB144\uC81C\uBAA9 Light",
                "\uACBD\uAE30\uCC9C\uB144\uC81C\uBAA9 Medium"
              ],
              "url": "https://cdn.jsdelivr.net/gh/projectnoonnu/2410-3@1.0/Title_Medium.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.afdb1042b3e581761dd7.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uACBD\uAE30\uCC9C\uB144\uC81C\uBAA9 Medium",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for `${CDN_GYEONGGI_MILLENNIUM}/Title_Medium.woff`",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uACBD\uAE30\uCC9C\uB144\uC81C\uBAA9 Medium",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "\uACBD\uAE30\uCC9C\uB144\uC81C\uBAA9 Medium"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uACBD\uAE30\uCC9C\uB144\uC81C\uBAA9 Bold",
                "\uACBD\uAE30\uCC9C\uB144\uC81C\uBAA9 Light",
                "\uACBD\uAE30\uCC9C\uB144\uC81C\uBAA9 Medium"
              ],
              "url": "https://cdn.jsdelivr.net/gh/projectnoonnu/2410-3@1.0/Title_Medium.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.24c7a7ed92e76b838f70.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB098\uB214\uBC14\uB978\uD39C",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for `${CDN_NOONFONTS_TWO}/NanumBarunpen.woff`",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uB098\uB214\uBC14\uB978\uD39C",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "\uB098\uB214\uBC14\uB978\uD39C"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uB098\uB214\uBC14\uB978\uD39C"
              ],
              "url": "https://cdn.jsdelivr.net/gh/projectnoonnu/noonfonts_two@1.0/NanumBarunpen.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.fe8c1e6bd80dc977481a.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB098\uB214\uC2A4\uD018\uC5B4\uB77C\uC6B4\uB4DC Bold",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for `${CDN_NOONFONTS_TWO}/NanumSquareRound.woff`",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uB098\uB214\uC2A4\uD018\uC5B4\uB77C\uC6B4\uB4DC Bold",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "\uB098\uB214\uC2A4\uD018\uC5B4\uB77C\uC6B4\uB4DC Bold"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uB098\uB214\uC2A4\uD018\uC5B4\uB77C\uC6B4\uB4DC Bold",
                "\uB098\uB214\uC2A4\uD018\uC5B4\uB77C\uC6B4\uB4DC ExtraBold",
                "\uB098\uB214\uC2A4\uD018\uC5B4\uB77C\uC6B4\uB4DC Regular"
              ],
              "url": "https://cdn.jsdelivr.net/gh/projectnoonnu/noonfonts_two@1.0/NanumSquareRound.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.a2fca4b269cbaf47e6fd.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB098\uB214\uC2A4\uD018\uC5B4\uB77C\uC6B4\uB4DC ExtraBold",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for `${CDN_NOONFONTS_TWO}/NanumSquareRound.woff`",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uB098\uB214\uC2A4\uD018\uC5B4\uB77C\uC6B4\uB4DC ExtraBold",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "\uB098\uB214\uC2A4\uD018\uC5B4\uB77C\uC6B4\uB4DC ExtraBold"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uB098\uB214\uC2A4\uD018\uC5B4\uB77C\uC6B4\uB4DC Bold",
                "\uB098\uB214\uC2A4\uD018\uC5B4\uB77C\uC6B4\uB4DC ExtraBold",
                "\uB098\uB214\uC2A4\uD018\uC5B4\uB77C\uC6B4\uB4DC Regular"
              ],
              "url": "https://cdn.jsdelivr.net/gh/projectnoonnu/noonfonts_two@1.0/NanumSquareRound.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.e0e80a5e2d2d694ead20.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB098\uB214\uC2A4\uD018\uC5B4\uB77C\uC6B4\uB4DC Regular",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for `${CDN_NOONFONTS_TWO}/NanumSquareRound.woff`",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uB098\uB214\uC2A4\uD018\uC5B4\uB77C\uC6B4\uB4DC Regular",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "\uB098\uB214\uC2A4\uD018\uC5B4\uB77C\uC6B4\uB4DC Regular"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uB098\uB214\uC2A4\uD018\uC5B4\uB77C\uC6B4\uB4DC Bold",
                "\uB098\uB214\uC2A4\uD018\uC5B4\uB77C\uC6B4\uB4DC ExtraBold",
                "\uB098\uB214\uC2A4\uD018\uC5B4\uB77C\uC6B4\uB4DC Regular"
              ],
              "url": "https://cdn.jsdelivr.net/gh/projectnoonnu/noonfonts_two@1.0/NanumSquareRound.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.ed221d8bc824fdeed8a4.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "62570\uCCB4",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'https://cdn.jsdelivr.net/npm/@noonnu/62570che@0.1.0/fonts/62570-normal.woff'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "62570\uCCB4",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "62570\uCCB4"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "62570\uCCB4"
              ],
              "url": "https://cdn.jsdelivr.net/npm/@noonnu/62570che@0.1.0/fonts/62570-normal.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.853f0809eee4e6b9daa9.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB098\uB214\uACE0\uB515 Light",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'https://cdn.jsdelivr.net/npm/@fontsource/nanum-gothic@5.3.0/files/nanum-gothic-0-400-normal.woff'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uB098\uB214\uACE0\uB515 Light",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "\uB098\uB214\uACE0\uB515 Light"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uB098\uB214\uACE0\uB515 Light"
              ],
              "url": "https://cdn.jsdelivr.net/npm/@fontsource/nanum-gothic@5.3.0/files/nanum-gothic-0-400-normal.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.66778cab409e2f8a43e1.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB098\uB214\uACE0\uB515OTF",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'https://cdn.jsdelivr.net/npm/@kfonts/nanum-gothic-otf@0.2.0/src/NanumGothic.otf'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uB098\uB214\uACE0\uB515OTF",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "\uB098\uB214\uACE0\uB515OTF"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uB098\uB214\uACE0\uB515OTF"
              ],
              "url": "https://cdn.jsdelivr.net/npm/@kfonts/nanum-gothic-otf@0.2.0/src/NanumGothic.otf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.64deb67e642ac428998b.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB098\uB214\uACE0\uB515OTF Bold",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'https://cdn.jsdelivr.net/npm/@kfonts/nanum-gothic-otf@0.2.0/src/NanumGothicBold.otf'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uB098\uB214\uACE0\uB515OTF Bold",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "\uB098\uB214\uACE0\uB515OTF Bold"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uB098\uB214\uACE0\uB515OTF Bold"
              ],
              "url": "https://cdn.jsdelivr.net/npm/@kfonts/nanum-gothic-otf@0.2.0/src/NanumGothicBold.otf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.f934e40df33952c15e3d.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB098\uB214\uBA85\uC870OTF ExtraBold",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'https://cdn.jsdelivr.net/npm/@kfonts/nanum-myeongjo-otf@0.2.0/src/NanumMyeongjoExtraBold.otf'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uB098\uB214\uBA85\uC870OTF ExtraBold",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "\uB098\uB214\uBA85\uC870OTF ExtraBold"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uB098\uB214\uBA85\uC870OTF ExtraBold"
              ],
              "url": "https://cdn.jsdelivr.net/npm/@kfonts/nanum-myeongjo-otf@0.2.0/src/NanumMyeongjoExtraBold.otf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.daeb146a5a3125ba10ff.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB098\uB214\uBC14\uB978\uACE0\uB515 Light",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'https://cdn.jsdelivr.net/npm/@kfonts/nanum-barun-gothic@0.3.0/NanumBarunGothicLight.woff'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uB098\uB214\uBC14\uB978\uACE0\uB515 Light",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "\uB098\uB214\uBC14\uB978\uACE0\uB515 Light"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uB098\uB214\uBC14\uB978\uACE0\uB515 Light"
              ],
              "url": "https://cdn.jsdelivr.net/npm/@kfonts/nanum-barun-gothic@0.3.0/NanumBarunGothicLight.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.d0ae1415680a6333f9d3.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB098\uB214\uBC14\uB978\uACE0\uB515OTF",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'https://cdn.jsdelivr.net/npm/@kfonts/nanum-barun-gothic-yet-hangul-otf@0.2.0/src/NanumBarunGothic-YetHangul.otf'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uB098\uB214\uBC14\uB978\uACE0\uB515OTF",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "\uB098\uB214\uBC14\uB978\uACE0\uB515OTF"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uB098\uB214\uBC14\uB978\uACE0\uB515OTF"
              ],
              "url": "https://cdn.jsdelivr.net/npm/@kfonts/nanum-barun-gothic-yet-hangul-otf@0.2.0/src/NanumBarunGothic-YetHangul.otf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.3bb7acf78e4978622599.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB098\uB214\uC2A4\uD018\uC5B4OTF",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'https://cdn.jsdelivr.net/npm/@kfonts/nanum-square-otf@0.2.0/src/NanumSquareB.otf'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uB098\uB214\uC2A4\uD018\uC5B4OTF",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "\uB098\uB214\uC2A4\uD018\uC5B4OTF"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uB098\uB214\uC2A4\uD018\uC5B4OTF"
              ],
              "url": "https://cdn.jsdelivr.net/npm/@kfonts/nanum-square-otf@0.2.0/src/NanumSquareB.otf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.4b6852096db05e93c258.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uB2E4\uC74C_SemiBold",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'https://cdn.jsdelivr.net/npm/alibabapuhuiti-3-75-semibold@1.0.0/AlibabaPuHuiTi-3-75-SemiBold.otf'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uB2E4\uC74C_SemiBold",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "\uB2E4\uC74C_SemiBold"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uB2E4\uC74C_SemiBold"
              ],
              "url": "https://cdn.jsdelivr.net/npm/alibabapuhuiti-3-75-semibold@1.0.0/AlibabaPuHuiTi-3-75-SemiBold.otf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.fda1a51097546a80890b.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uC5D0\uC2A4\uCF54\uC5B4 \uB4DC\uB9BC 3 Light",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'https://cdn.jsdelivr.net/npm/@noonnu/s-core-dream-3-light@0.1.0/fonts/s-coredream-3light-normal.woff'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uC5D0\uC2A4\uCF54\uC5B4 \uB4DC\uB9BC 3 Light",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "\uC5D0\uC2A4\uCF54\uC5B4 \uB4DC\uB9BC 3 Light"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uC5D0\uC2A4\uCF54\uC5B4 \uB4DC\uB9BC 3 Light"
              ],
              "url": "https://cdn.jsdelivr.net/npm/@noonnu/s-core-dream-3-light@0.1.0/fonts/s-coredream-3light-normal.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.829e641bf7d97c4b41e3.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Baskerville BT",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'https://cdn.jsdelivr.net/npm/@fontsource/libre-baskerville@5.3.0/files/libre-baskerville-latin-400-italic.woff'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Baskerville BT",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "Baskerville BT"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "Baskerville BT"
              ],
              "url": "https://cdn.jsdelivr.net/npm/@fontsource/libre-baskerville@5.3.0/files/libre-baskerville-latin-400-italic.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.ed00e50e6310822e1a16.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Bodoni Bd BT",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'https://cdn.jsdelivr.net/npm/@fontsource/bodoni-moda@5.3.0/files/bodoni-moda-latin-400-italic.woff'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Bodoni Bd BT",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "Bodoni Bd BT"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "Bodoni Bd BT",
                "Bodoni Bk BT",
                "Bodoni MT"
              ],
              "url": "https://cdn.jsdelivr.net/npm/@fontsource/bodoni-moda@5.3.0/files/bodoni-moda-latin-400-italic.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.a24633a420802036ba08.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Bodoni Bk BT",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'https://cdn.jsdelivr.net/npm/@fontsource/bodoni-moda@5.3.0/files/bodoni-moda-latin-400-italic.woff'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Bodoni Bk BT",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "Bodoni Bk BT"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "Bodoni Bd BT",
                "Bodoni Bk BT",
                "Bodoni MT"
              ],
              "url": "https://cdn.jsdelivr.net/npm/@fontsource/bodoni-moda@5.3.0/files/bodoni-moda-latin-400-italic.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.66b7fa1b21caa72ae8b5.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Bodoni MT",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'https://cdn.jsdelivr.net/npm/@fontsource/bodoni-moda@5.3.0/files/bodoni-moda-latin-400-italic.woff'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Bodoni MT",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "Bodoni MT"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "Bodoni Bd BT",
                "Bodoni Bk BT",
                "Bodoni MT"
              ],
              "url": "https://cdn.jsdelivr.net/npm/@fontsource/bodoni-moda@5.3.0/files/bodoni-moda-latin-400-italic.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.f9b7ce3f9ecfedc26c08.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "BrushScript BT",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'https://cdn.jsdelivr.net/npm/@fontsource/nanum-brush-script@5.3.0/files/nanum-brush-script-0-400-normal.woff'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "BrushScript BT",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "BrushScript BT"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "BrushScript BT"
              ],
              "url": "https://cdn.jsdelivr.net/npm/@fontsource/nanum-brush-script@5.3.0/files/nanum-brush-script-0-400-normal.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.6a68839caf882e5c47f9.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Calisto MT",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'https://cdn.jsdelivr.net/npm/@fontsource/calistoga@5.3.0/files/calistoga-latin-400-normal.woff'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Calisto MT",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "Calisto MT"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "Calisto MT"
              ],
              "url": "https://cdn.jsdelivr.net/npm/@fontsource/calistoga@5.3.0/files/calistoga-latin-400-normal.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.a3ab877d557ae3620dc9.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Century Schoolbook",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'https://cdn.jsdelivr.net/npm/centschbook-mono@3.2.1/Century-Schoolbook-Monospace-BT.ttf'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Century Schoolbook",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "Century Schoolbook"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "Century Schoolbook"
              ],
              "url": "https://cdn.jsdelivr.net/npm/centschbook-mono@3.2.1/Century-Schoolbook-Monospace-BT.ttf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.901b6b211f4fcfa54768.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "FangSong",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'https://cdn.jsdelivr.net/npm/@fontpkg/zhuque-fangsong-technical-preview@0.212.0/ZhuqueFangsong-Regular.ttf'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "FangSong",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "FangSong"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "FangSong"
              ],
              "url": "https://cdn.jsdelivr.net/npm/@fontpkg/zhuque-fangsong-technical-preview@0.212.0/ZhuqueFangsong-Regular.ttf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.15884b9e7c1f2a7c4ee9.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Futura Hv BT",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'https://cdn.jsdelivr.net/npm/futura-font@1.0.0/FuturaBT-Medium.ttf'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Futura Hv BT",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "Futura Hv BT"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "Futura Hv BT"
              ],
              "url": "https://cdn.jsdelivr.net/npm/futura-font@1.0.0/FuturaBT-Medium.ttf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.64ceaf9e0bb28ae5c942.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Garamond",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'https://cdn.jsdelivr.net/npm/@fontsource/cormorant-garamond@5.3.0/files/cormorant-garamond-cyrillic-300-italic.woff'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Garamond",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "Garamond"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "Garamond"
              ],
              "url": "https://cdn.jsdelivr.net/npm/@fontsource/cormorant-garamond@5.3.0/files/cormorant-garamond-cyrillic-300-italic.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.2ce5d402e8711133d375.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "HCRDotum",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'https://cdn.jsdelivr.net/npm/@noonnu/hcr-dotum@0.1.0/fonts/hcrdotum-normal.woff'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "HCRDotum",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "HCRDotum"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "HCRDotum"
              ],
              "url": "https://cdn.jsdelivr.net/npm/@noonnu/hcr-dotum@0.1.0/fonts/hcrdotum-normal.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.9c94b159bdd08dbaa68f.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Helvetica",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'https://cdn.jsdelivr.net/npm/helvetica-original@1.0.0/Black/Helvetica-Black.ttf'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Helvetica",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "Helvetica"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "Helvetica"
              ],
              "url": "https://cdn.jsdelivr.net/npm/helvetica-original@1.0.0/Black/Helvetica-Black.ttf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.4ec2b847f6c75730609a.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Helvetica 65 Medium",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'https://cdn.jsdelivr.net/npm/@duppla-font/helvetica-now@1.0.0/files/HelveticaNowTextMedium.otf'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Helvetica 65 Medium",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "Helvetica 65 Medium"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "Helvetica 65 Medium"
              ],
              "url": "https://cdn.jsdelivr.net/npm/@duppla-font/helvetica-now@1.0.0/files/HelveticaNowTextMedium.otf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.0d9e89207f8f7d90215a.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Helvetica Neue",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'https://cdn.jsdelivr.net/npm/@marcius-studio/font@0.0.1/HelveticaNeueCyr/HelveticaNeueCyr-Black.ttf'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Helvetica Neue",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "Helvetica Neue"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "Helvetica Neue"
              ],
              "url": "https://cdn.jsdelivr.net/npm/@marcius-studio/font@0.0.1/HelveticaNeueCyr/HelveticaNeueCyr-Black.ttf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.55003aecf83027a605cd.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "KBIZ\uD55C\uB9C8\uC74C\uBA85\uC870 R",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'https://cdn.jsdelivr.net/npm/@noonnu/kbiz-hanmaum-myungjo@0.1.0/fonts/kbizhanmaummyungjo-normal.woff'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "KBIZ\uD55C\uB9C8\uC74C\uBA85\uC870 R",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "KBIZ\uD55C\uB9C8\uC74C\uBA85\uC870 R"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "KBIZ\uD55C\uB9C8\uC74C\uBA85\uC870 R"
              ],
              "url": "https://cdn.jsdelivr.net/npm/@noonnu/kbiz-hanmaum-myungjo@0.1.0/fonts/kbizhanmaummyungjo-normal.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.7c1ae0bbafc6cdefe9af.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "MS Gothic",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'https://cdn.jsdelivr.net/npm/@fontsource/zen-maru-gothic@5.3.0/files/zen-maru-gothic-10-300-normal.woff'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "MS Gothic",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "MS Gothic"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "MS Gothic",
                "MS UI Gothic"
              ],
              "url": "https://cdn.jsdelivr.net/npm/@fontsource/zen-maru-gothic@5.3.0/files/zen-maru-gothic-10-300-normal.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.095c1c232dbb4dfb5cc2.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "MS Mincho",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'https://cdn.jsdelivr.net/npm/@fontsource/shippori-mincho@5.3.0/files/shippori-mincho-0-400-normal.woff'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "MS Mincho",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "MS Mincho"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "MS Mincho",
                "Yu Mincho"
              ],
              "url": "https://cdn.jsdelivr.net/npm/@fontsource/shippori-mincho@5.3.0/files/shippori-mincho-0-400-normal.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.d3e8b09ed17746beaa6a.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "MS Song",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'https://cdn.jsdelivr.net/npm/@fontsource/song-myung@5.3.0/files/song-myung-10-400-normal.woff'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "MS Song",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "MS Song"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "MS Song"
              ],
              "url": "https://cdn.jsdelivr.net/npm/@fontsource/song-myung@5.3.0/files/song-myung-10-400-normal.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.f3ea7acc996fe24a3604.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "MS UI Gothic",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'https://cdn.jsdelivr.net/npm/@fontsource/zen-maru-gothic@5.3.0/files/zen-maru-gothic-10-300-normal.woff'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "MS UI Gothic",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "MS UI Gothic"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "MS Gothic",
                "MS UI Gothic"
              ],
              "url": "https://cdn.jsdelivr.net/npm/@fontsource/zen-maru-gothic@5.3.0/files/zen-maru-gothic-10-300-normal.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.3c6f59d992a9c3bc6797.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "MT Extra",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'https://cdn.jsdelivr.net/npm/@fontsource/fira-sans-extra-condensed@5.3.0/files/fira-sans-extra-condensed-cyrillic-100-italic.woff'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "MT Extra",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "MT Extra"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "MT Extra"
              ],
              "url": "https://cdn.jsdelivr.net/npm/@fontsource/fira-sans-extra-condensed@5.3.0/files/fira-sans-extra-condensed-cyrillic-100-italic.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.617b2457d3e4b9fef10f.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Myeongjo",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'https://cdn.jsdelivr.net/npm/@fontsource/nanum-myeongjo@5.3.0/files/nanum-myeongjo-0-400-normal.woff'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Myeongjo",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "Myeongjo"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "Myeongjo"
              ],
              "url": "https://cdn.jsdelivr.net/npm/@fontsource/nanum-myeongjo@5.3.0/files/nanum-myeongjo-0-400-normal.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.41f4abc361abb59f405b.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Nanum Barun Gothic",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'https://cdn.jsdelivr.net/npm/@kfonts/nanum-barun-gothic@0.3.0/NanumBarunGothic.woff'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Nanum Barun Gothic",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "Nanum Barun Gothic"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "Nanum Barun Gothic"
              ],
              "url": "https://cdn.jsdelivr.net/npm/@kfonts/nanum-barun-gothic@0.3.0/NanumBarunGothic.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.f8bd9d02732ea351cd32.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Noto",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'https://cdn.jsdelivr.net/npm/@fontsource/noto-sans-jp@5.3.0/files/noto-sans-jp-0-100-normal.woff'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Noto",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "Noto"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "Noto"
              ],
              "url": "https://cdn.jsdelivr.net/npm/@fontsource/noto-sans-jp@5.3.0/files/noto-sans-jp-0-100-normal.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.255312354238713953d0.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Noto Sans CJK JP Regular",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'https://cdn.jsdelivr.net/npm/noto-sans-cjk-jp@1.0.1/fonts/NotoSansCJKjp-Regular.woff'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Noto Sans CJK JP Regular",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "Noto Sans CJK JP Regular"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "Noto Sans CJK JP Regular"
              ],
              "url": "https://cdn.jsdelivr.net/npm/noto-sans-cjk-jp@1.0.1/fonts/NotoSansCJKjp-Regular.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.95f9511d889a697b4c8a.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Segoe UI",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'https://cdn.jsdelivr.net/npm/@fontpkg/segoe-ui@5.67.0/segoeui.ttf'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Segoe UI",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "Segoe UI"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "Segoe UI"
              ],
              "url": "https://cdn.jsdelivr.net/npm/@fontpkg/segoe-ui@5.67.0/segoeui.ttf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.5d2cb1564c2f5ad4dcd6.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "SimSun",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'https://cdn.jsdelivr.net/npm/react-native-font-sim@2.0.1/fonts/SimSun.ttf'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "SimSun",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "SimSun"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "SimSun"
              ],
              "url": "https://cdn.jsdelivr.net/npm/react-native-font-sim@2.0.1/fonts/SimSun.ttf"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.c52db9881ba457f5c392.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Yu Mincho",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'https://cdn.jsdelivr.net/npm/@fontsource/shippori-mincho@5.3.0/files/shippori-mincho-0-400-normal.woff'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Yu Mincho",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [],
          "unavailableFonts": [
            "Yu Mincho"
          ]
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "MS Mincho",
                "Yu Mincho"
              ],
              "url": "https://cdn.jsdelivr.net/npm/@fontsource/shippori-mincho@5.3.0/files/shippori-mincho-0-400-normal.woff"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.95f071bf284bacec28b6.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "D2Coding",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/D2Coding-Regular.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "D2Coding",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uAD74\uB9BC\uCCB4",
                "\uBC14\uD0D5\uCCB4",
                "D2Coding"
              ],
              "url": "fonts/D2Coding-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uAD74\uB9BC\uCCB4",
                "\uBC14\uD0D5\uCCB4",
                "D2Coding"
              ],
              "url": "fonts/D2Coding-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.89fc1e92518accb512a3.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uD574\uD53C\uB2C8\uC2A4 \uC0B0\uC2A4 \uB808\uADE4\uB7EC",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/Happiness-Sans-Regular.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uD574\uD53C\uB2C8\uC2A4 \uC0B0\uC2A4 \uB808\uADE4\uB7EC",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uD574\uD53C\uB2C8\uC2A4 \uC0B0\uC2A4 \uB808\uADE4\uB7EC",
                "Happiness Sans Regular"
              ],
              "url": "fonts/Happiness-Sans-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uD574\uD53C\uB2C8\uC2A4 \uC0B0\uC2A4 \uB808\uADE4\uB7EC",
                "Happiness Sans Regular"
              ],
              "url": "fonts/Happiness-Sans-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.7fa94fcf4b29abfb99e2.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Happiness Sans Regular",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/Happiness-Sans-Regular.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Happiness Sans Regular",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uD574\uD53C\uB2C8\uC2A4 \uC0B0\uC2A4 \uB808\uADE4\uB7EC",
                "Happiness Sans Regular"
              ],
              "url": "fonts/Happiness-Sans-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uD574\uD53C\uB2C8\uC2A4 \uC0B0\uC2A4 \uB808\uADE4\uB7EC",
                "Happiness Sans Regular"
              ],
              "url": "fonts/Happiness-Sans-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.9f0b2b27b2e1cdcf48c9.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uD574\uD53C\uB2C8\uC2A4 \uC0B0\uC2A4 \uBCFC\uB4DC",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/Happiness-Sans-Bold.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uD574\uD53C\uB2C8\uC2A4 \uC0B0\uC2A4 \uBCFC\uB4DC",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uD574\uD53C\uB2C8\uC2A4 \uC0B0\uC2A4 \uBCFC\uB4DC",
                "Happiness Sans Bold"
              ],
              "url": "fonts/Happiness-Sans-Bold.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uD574\uD53C\uB2C8\uC2A4 \uC0B0\uC2A4 \uBCFC\uB4DC",
                "Happiness Sans Bold"
              ],
              "url": "fonts/Happiness-Sans-Bold.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.ed42872fd0faa00ab14c.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Happiness Sans Bold",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/Happiness-Sans-Bold.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Happiness Sans Bold",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uD574\uD53C\uB2C8\uC2A4 \uC0B0\uC2A4 \uBCFC\uB4DC",
                "Happiness Sans Bold"
              ],
              "url": "fonts/Happiness-Sans-Bold.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uD574\uD53C\uB2C8\uC2A4 \uC0B0\uC2A4 \uBCFC\uB4DC",
                "Happiness Sans Bold"
              ],
              "url": "fonts/Happiness-Sans-Bold.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.a98320b11ca23a757549.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uD574\uD53C\uB2C8\uC2A4 \uC0B0\uC2A4 \uD0C0\uC774\uD2C0",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/Happiness-Sans-Title.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uD574\uD53C\uB2C8\uC2A4 \uC0B0\uC2A4 \uD0C0\uC774\uD2C0",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uD574\uD53C\uB2C8\uC2A4 \uC0B0\uC2A4 \uD0C0\uC774\uD2C0",
                "Happiness Sans Title"
              ],
              "url": "fonts/Happiness-Sans-Title.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uD574\uD53C\uB2C8\uC2A4 \uC0B0\uC2A4 \uD0C0\uC774\uD2C0",
                "Happiness Sans Title"
              ],
              "url": "fonts/Happiness-Sans-Title.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.235d312a1bcaa5223d51.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Happiness Sans Title",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/Happiness-Sans-Title.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Happiness Sans Title",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uD574\uD53C\uB2C8\uC2A4 \uC0B0\uC2A4 \uD0C0\uC774\uD2C0",
                "Happiness Sans Title"
              ],
              "url": "fonts/Happiness-Sans-Title.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uD574\uD53C\uB2C8\uC2A4 \uC0B0\uC2A4 \uD0C0\uC774\uD2C0",
                "Happiness Sans Title"
              ],
              "url": "fonts/Happiness-Sans-Title.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.7addb14ca54d3478ff11.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uD574\uD53C\uB2C8\uC2A4 \uC0B0\uC2A4 VF",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/HappinessSansVF.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uD574\uD53C\uB2C8\uC2A4 \uC0B0\uC2A4 VF",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uD574\uD53C\uB2C8\uC2A4 \uC0B0\uC2A4 VF",
                "Happiness Sans VF"
              ],
              "url": "fonts/HappinessSansVF.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uD574\uD53C\uB2C8\uC2A4 \uC0B0\uC2A4 VF",
                "Happiness Sans VF"
              ],
              "url": "fonts/HappinessSansVF.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.6ed322eba70a28f851f5.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Happiness Sans VF",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/HappinessSansVF.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Happiness Sans VF",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uD574\uD53C\uB2C8\uC2A4 \uC0B0\uC2A4 VF",
                "Happiness Sans VF"
              ],
              "url": "fonts/HappinessSansVF.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uD574\uD53C\uB2C8\uC2A4 \uC0B0\uC2A4 VF",
                "Happiness Sans VF"
              ],
              "url": "fonts/HappinessSansVF.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.064b5392c04262fb4a31.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Cafe24 Ssurround Bold",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/Cafe24Ssurround-v2.0.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Cafe24 Ssurround Bold",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "Cafe24 Ssurround Bold"
              ],
              "url": "fonts/Cafe24Ssurround-v2.0.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "Cafe24 Ssurround Bold"
              ],
              "url": "fonts/Cafe24Ssurround-v2.0.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.9e9d6be2e5d060c37893.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uCE74\uD39824 \uC288\uD37C\uB9E4\uC9C1",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/Cafe24Supermagic-Regular-v1.0.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uCE74\uD39824 \uC288\uD37C\uB9E4\uC9C1",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uCE74\uD39824 \uC288\uD37C\uB9E4\uC9C1",
                "Cafe24 Supermagic"
              ],
              "url": "fonts/Cafe24Supermagic-Regular-v1.0.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uCE74\uD39824 \uC288\uD37C\uB9E4\uC9C1",
                "Cafe24 Supermagic"
              ],
              "url": "fonts/Cafe24Supermagic-Regular-v1.0.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.cadf006c804cd692d83d.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Cafe24 Supermagic",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/Cafe24Supermagic-Regular-v1.0.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Cafe24 Supermagic",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uCE74\uD39824 \uC288\uD37C\uB9E4\uC9C1",
                "Cafe24 Supermagic"
              ],
              "url": "fonts/Cafe24Supermagic-Regular-v1.0.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uCE74\uD39824 \uC288\uD37C\uB9E4\uC9C1",
                "Cafe24 Supermagic"
              ],
              "url": "fonts/Cafe24Supermagic-Regular-v1.0.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.fb1ba6d9a29aa201f8ee.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Latin Modern Math",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/LatinModernMath-Regular.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Latin Modern Math",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "Latin Modern Math"
              ],
              "url": "fonts/LatinModernMath-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "Latin Modern Math"
              ],
              "url": "fonts/LatinModernMath-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.217e88329fd93b1b4b7d.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "SpoqaHanSans",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/SpoqaHanSans-Regular.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "SpoqaHanSans",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "SpoqaHanSans"
              ],
              "url": "fonts/SpoqaHanSans-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "SpoqaHanSans"
              ],
              "url": "fonts/SpoqaHanSans-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.5031552686798f2c6ca4.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uACE0\uC6B4\uBC14\uD0D5",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/GowunBatang-Regular.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uACE0\uC6B4\uBC14\uD0D5",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uACE0\uC6B4\uBC14\uD0D5",
                "\uAD81\uC11C",
                "\uAD81\uC11C\uCCB4",
                "\uC0C8\uAD81\uC11C"
              ],
              "url": "fonts/GowunBatang-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uACE0\uC6B4\uBC14\uD0D5",
                "\uAD81\uC11C",
                "\uAD81\uC11C\uCCB4",
                "\uC0C8\uAD81\uC11C"
              ],
              "url": "fonts/GowunBatang-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.673ef286e7424d121b88.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uACE0\uC6B4\uB3CB\uC6C0",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/GowunDodum-Regular.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "\uACE0\uC6B4\uB3CB\uC6C0",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "\uACE0\uC6B4\uB3CB\uC6C0"
              ],
              "url": "fonts/GowunDodum-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "\uACE0\uC6B4\uB3CB\uC6C0"
              ],
              "url": "fonts/GowunDodum-Regular.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.0aab2d58429b52047acb.canvaskit",
      "sourceBoundaryId": "studio-supply.font-list",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "Source Han Serif K Old Hangul",
      "targetFaceOrPolicy": "unavailable: no CanvasKit SFNT source for 'fonts/SourceHanSerifK-OldHangul-subset.woff2'",
      "conditions": {
        "profile": "canvaskit-sfnt"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": {
        "capabilityAgreement": false,
        "declaredCapability": "unavailable",
        "fontFamily": "Source Han Serif K Old Hangul",
        "kind": "canvaskit-plan",
        "offline": {
          "sources": [
            {
              "aliases": [
                "Source Han Serif K Old Hangul"
              ],
              "url": "fonts/SourceHanSerifK-OldHangul-subset.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "online": {
          "sources": [
            {
              "aliases": [
                "Source Han Serif K Old Hangul"
              ],
              "url": "fonts/SourceHanSerifK-OldHangul-subset.woff2"
            }
          ],
          "unavailableFonts": []
        },
        "runtimePlanStatus": "planned"
      }
    },
    {
      "ruleId": "rule.studio-supply.46fe921c63519b834a98",
      "sourceBoundaryId": "studio-supply.canvaskit-plan",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uD734\uBA3C\uBA85\uC870",
      "targetFaceOrPolicy": "HY\uC2E0\uBA85\uC870",
      "conditions": {
        "profile": "canvaskit"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-supply.8c1d7ff9afc345a4e0e6",
      "sourceBoundaryId": "studio-supply.canvaskit-plan",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uD55C\uC591\uC911\uACE0\uB515",
      "targetFaceOrPolicy": "HY\uC911\uACE0\uB515",
      "conditions": {
        "profile": "canvaskit"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-supply.42a29aa55fdc0eb2f270",
      "sourceBoundaryId": "studio-supply.canvaskit-plan",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": "\uD55C\uCEF4 \uC724\uACE0\uB515 230",
      "targetFaceOrPolicy": "Noto Sans KR ExtraLight",
      "conditions": {
        "profile": "canvaskit"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-supply.f8d718ee50988a4bc31e",
      "sourceBoundaryId": "studio-supply.canvaskit-plan",
      "relationType": "supply-source",
      "decisionPlane": "supply",
      "sourceFace": null,
      "targetFaceOrPolicy": "resolve requested families to FONT_LIST bytes, group aliases by URL, and fail unavailable fonts closed",
      "conditions": {
        "profile": "canvaskit"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    },
    {
      "ruleId": "rule.studio-detection.dc427cacdd59d822e9e2",
      "sourceBoundaryId": "studio-detection.sfnt-bytes",
      "relationType": "capability-detection",
      "decisionPlane": "detection",
      "sourceFace": null,
      "targetFaceOrPolicy": "read approved exact PostScript faces in one batch without persistent byte caching",
      "conditions": {
        "profile": "canvaskit"
      },
      "order": null,
      "mode": "direct",
      "metricEntryIds": [],
      "supply": null
    }
  ]);

  // build.noindex/task567/stage3-2/upstream-v087/rhwp-studio/src/core/font-rule-runtime.ts
  var SUBSTITUTION_BOUNDARY = "studio-substitution.substitution-tables";
  var GOVERNMENT_SUCCESSOR_BOUNDARY = "rust-paint-chain.installed-aliases";
  var DISPLAY_CHAIN_BOUNDARY = "studio-substitution.display-chain";
  var WEBFONT_BOUNDARY = "studio-supply.font-list";
  var CANVASKIT_PLAN_BOUNDARY = "studio-supply.canvaskit-plan";
  function hasBoundary(rule, boundary) {
    return rule.sourceBoundaryId === boundary;
  }
  function requiredString(value, key2, ruleId) {
    const result = value[key2];
    if (typeof result !== "string" || result.length === 0) {
      throw new Error(`${ruleId}: generated font supply ${key2} must be a non-empty string`);
    }
    return result;
  }
  function nullableString(value, key2, ruleId) {
    const result = value[key2];
    if (result === null || result === void 0) return null;
    if (typeof result !== "string") {
      throw new Error(`${ruleId}: generated font supply ${key2} must be a string or null`);
    }
    return result;
  }
  function supplyObject(rule) {
    if (rule.supply === null) {
      throw new Error(`${rule.ruleId}: generated font supply payload is missing`);
    }
    return rule.supply;
  }
  function parseSubstitutionAltTypes(rule) {
    const match = /^source:(\d+)->target:(\d+)$/.exec(rule.conditions.altType ?? "");
    if (!match) throw new Error(`${rule.ruleId}: generated substitution altType is invalid`);
    return [Number.parseInt(match[1], 10), Number.parseInt(match[2], 10)];
  }
  var FONT_RULE_SUBSTITUTION_TABLES = Object.freeze(Array.from({ length: 7 }, (_, languageSlot) => Object.freeze(
    FONT_RULE_CANVAS2D_PAINT_RULES.filter((rule) => hasBoundary(rule, SUBSTITUTION_BOUNDARY) && rule.conditions.languageSlot === String(languageSlot)).sort((left, right) => (left.order ?? 0) - (right.order ?? 0)).map((rule) => {
      if (rule.sourceFace === null) {
        throw new Error(`${rule.ruleId}: generated substitution sourceFace is missing`);
      }
      const [sourceAltType, targetAltType] = parseSubstitutionAltTypes(rule);
      return Object.freeze([
        rule.sourceFace,
        sourceAltType,
        rule.targetFaceOrPolicy,
        targetAltType,
        rule.ruleId
      ]);
    })
  )));
  var substitutionIndexes = Array.from({ length: 7 }, () => null);
  var FONT_RULE_GOVERNMENT_SUCCESSORS = Object.freeze(FONT_RULE_CANVAS2D_PAINT_RULES.filter((rule) => hasBoundary(rule, GOVERNMENT_SUCCESSOR_BOUNDARY)).map((rule) => {
    if (rule.sourceFace === null || rule.order === null) {
      throw new Error(`${rule.ruleId}: generated government successor is incomplete`);
    }
    return Object.freeze({
      sourceFace: rule.sourceFace,
      targetFace: rule.targetFaceOrPolicy,
      order: rule.order,
      ruleId: rule.ruleId
    });
  }));
  var FONT_RULE_DISPLAY_CHAIN_POLICY_IDS = Object.freeze(Object.fromEntries(
    FONT_RULE_CANVAS2D_PAINT_RULES.filter((rule) => hasBoundary(rule, DISPLAY_CHAIN_BOUNDARY)).map((rule) => [rule.relationType, rule.ruleId])
  ));
  var FONT_RULE_WEBFONT_ENTRIES = Object.freeze(
    FONT_RULE_CANVAS2D_WEBFONT_RULES.map((rule) => {
      if (!hasBoundary(rule, WEBFONT_BOUNDARY)) {
        throw new Error(`${rule.ruleId}: unexpected webfont source boundary`);
      }
      const supply = supplyObject(rule);
      const format = requiredString(supply, "format", rule.ruleId);
      if (!["woff2", "woff", "truetype", "opentype"].includes(format)) {
        throw new Error(`${rule.ruleId}: generated webfont format is invalid`);
      }
      const unicodeRange = nullableString(supply, "unicodeRange", rule.ruleId);
      return Object.freeze({
        name: requiredString(supply, "fontFamily", rule.ruleId),
        file: requiredString(supply, "sourceUrl", rule.ruleId),
        format,
        ...unicodeRange === null ? {} : { unicodeRange },
        ruleId: rule.ruleId
      });
    })
  );
  function stringArray(value, location) {
    if (!Array.isArray(value) || value.some((entry) => typeof entry !== "string")) {
      throw new Error(`${location} must be a string array`);
    }
    return [...value];
  }
  function canvasKitSnapshot(value, location) {
    if (value === null || typeof value !== "object" || Array.isArray(value)) {
      throw new Error(`${location} must be an object`);
    }
    const record = value;
    if (!Array.isArray(record.sources)) throw new Error(`${location}.sources must be an array`);
    const sources = record.sources.map((source, index) => {
      if (source === null || typeof source !== "object" || Array.isArray(source)) {
        throw new Error(`${location}.sources[${index}] must be an object`);
      }
      const sourceRecord = source;
      return {
        url: requiredString(sourceRecord, "url", location),
        aliases: stringArray(sourceRecord.aliases, `${location}.sources[${index}].aliases`)
      };
    });
    return {
      sources,
      unavailableFonts: stringArray(record.unavailableFonts, `${location}.unavailableFonts`)
    };
  }
  var canvasKitSupplyRules = FONT_RULE_CANVASKIT_SFNT_RULES.filter((rule) => hasBoundary(rule, WEBFONT_BOUNDARY));
  var canvasKitSupplies = new Map(canvasKitSupplyRules.map((rule) => {
    if (rule.sourceFace === null) {
      throw new Error(`${rule.ruleId}: generated CanvasKit font family is missing`);
    }
    const supply = supplyObject(rule);
    return [normalizeProjectedFontFamily(rule.sourceFace), {
      sourceFace: rule.sourceFace,
      declaredCapability: requiredString(supply, "declaredCapability", rule.ruleId),
      online: canvasKitSnapshot(supply.online, `${rule.ruleId}.online`),
      offline: canvasKitSnapshot(supply.offline, `${rule.ruleId}.offline`),
      ruleId: rule.ruleId
    }];
  }));
  var canvasKitSubstitutes = new Map(
    FONT_RULE_CANVASKIT_SFNT_RULES.filter((rule) => hasBoundary(rule, CANVASKIT_PLAN_BOUNDARY) && rule.sourceFace !== null).map((rule) => [normalizeProjectedFontFamily(rule.sourceFace ?? ""), {
      target: normalizeProjectedFontFamily(rule.targetFaceOrPolicy),
      ruleId: rule.ruleId
    }])
  );
  var canvasKitPlanPolicyRule = FONT_RULE_CANVASKIT_SFNT_RULES.find((rule) => hasBoundary(rule, CANVASKIT_PLAN_BOUNDARY) && rule.sourceFace === null);
  if (!canvasKitPlanPolicyRule) throw new Error("generated CanvasKit plan policy is missing");
  var canvasKitPlanPolicyRuleId = canvasKitPlanPolicyRule.ruleId;
  function normalizeProjectedFontFamily(value) {
    return value.replace(/\u0000/g, "").normalize("NFC").replace(/\s+/g, " ").trim().toLocaleLowerCase("en-US");
  }

  // build.noindex/task567/stage3-2/upstream-v087/rhwp-studio/src/core/font-loader.ts
  var FONT_LIST = FONT_RULE_WEBFONT_ENTRIES;
  var REGISTERED_FONTS = new Set(FONT_LIST.map((f) => f.name));

  // build.noindex/task567/stage3-2/upstream-v087/rhwp-studio/src/core/local-fonts.ts
  var cachedFontLookup = emptyLocalFontLookup();
  function normalizeFontAlias(value) {
    if (typeof value !== "string") return "";
    return value.replace(/\u0000/g, "").normalize("NFC").replace(/\s+/g, " ").trim().toLocaleLowerCase("en-US");
  }
  function normalizeFontNames(values) {
    const byAlias = /* @__PURE__ */ new Map();
    for (const value of values) {
      if (typeof value !== "string") continue;
      const name2 = value.replace(/\u0000/g, "").normalize("NFC").replace(/\s+/g, " ").trim();
      const alias = normalizeFontAlias(name2);
      if (alias && !byAlias.has(alias)) byAlias.set(alias, name2);
    }
    return Array.from(byAlias.values()).sort((a, b) => a.localeCompare(b, "ko"));
  }
  function emptyLocalFontLookup() {
    return {
      aliases: /* @__PURE__ */ new Map(),
      postscriptNames: /* @__PURE__ */ new Map(),
      fullNames: /* @__PURE__ */ new Map(),
      familyStyles: /* @__PURE__ */ new Map(),
      families: /* @__PURE__ */ new Map()
    };
  }
  function addLocalFontLookupRecord(index, name2, record, normalizedNameCache) {
    let key2 = normalizedNameCache.get(name2);
    if (key2 === void 0) {
      key2 = normalizeFontAlias(name2);
      normalizedNameCache.set(name2, key2);
    }
    if (!key2) return;
    const records = index.get(key2);
    if (!records) {
      index.set(key2, [record]);
    } else if (!records.includes(record)) {
      records.push(record);
    }
  }
  function buildLocalFontLookup(records) {
    const lookup = emptyLocalFontLookup();
    const normalizedNameCache = /* @__PURE__ */ new Map();
    for (const record of records) {
      for (const alias of record.aliases) {
        addLocalFontLookupRecord(lookup.aliases, alias, record, normalizedNameCache);
      }
      addLocalFontLookupRecord(lookup.postscriptNames, record.postscriptName, record, normalizedNameCache);
      addLocalFontLookupRecord(lookup.fullNames, record.fullName, record, normalizedNameCache);
      addLocalFontLookupRecord(lookup.familyStyles, `${record.family} ${record.style}`, record, normalizedNameCache);
      addLocalFontLookupRecord(lookup.families, record.family, record, normalizedNameCache);
    }
    return lookup;
  }
  function resolveLocalFontFromLookup(fontName, lookup) {
    const target = normalizeFontAlias(fontName);
    if (!target) return null;
    const matches = lookup.aliases.get(target) ?? [];
    if (matches.length === 0) return null;
    const uniqueMatch = (records) => records?.length === 1 ? records[0] : null;
    return uniqueMatch(lookup.postscriptNames.get(target)) ?? uniqueMatch(lookup.fullNames.get(target)) ?? uniqueMatch(lookup.familyStyles.get(target)) ?? uniqueMatch(lookup.families.get(target)) ?? (matches.length === 1 ? matches[0] : null);
  }
  function resolveLocalFont(fontName) {
    return resolveLocalFontFromLookup(fontName, cachedFontLookup);
  }
  var hostFontSource = new HostFontSource();
  var hostLookupGeneration = -1;
  var hostLookupReferences = [];
  var hostRecords = [];
  var hostLookup = emptyLocalFontLookup();
  hostFontSource.subscribe(() => {
    hostLookupGeneration = -1;
    hostLookupReferences = [];
    hostRecords = [];
    hostLookup = emptyLocalFontLookup();
  });
  function setHostFontProvider(provider) {
    return hostFontSource.setProvider(provider);
  }
  function prepareHostFontCatalog() {
    return hostFontSource.ready();
  }
  function currentHostRecords() {
    const references = hostFontSource.references();
    if (hostLookupGeneration !== hostFontSource.generation || references[0]?.face !== hostLookupReferences[0]?.face || references.length !== hostLookupReferences.length) {
      hostLookupGeneration = hostFontSource.generation;
      hostLookupReferences = references;
      hostRecords = references.map((reference) => {
        const face = reference.face;
        return {
          family: face.family,
          fullName: face.fullName,
          postscriptName: face.postscriptName,
          style: face.style,
          displayName: face.fullName,
          aliases: normalizeFontNames([
            face.family,
            face.fullName,
            face.postscriptName,
            `${face.family} ${face.style}`,
            ...face.aliases ?? []
          ]),
          hostReference: reference
        };
      });
      hostLookup = buildLocalFontLookup(hostRecords);
    }
    return hostRecords;
  }
  function resolveRendererLocalFont(name2, style) {
    if (!hostFontSource.active) return resolveLocalFont(name2);
    const target = normalizeFontAlias(name2);
    currentHostRecords();
    const candidates = hostLookup.aliases.get(target) ?? [];
    const postscript = hostLookup.postscriptNames.get(target) ?? [];
    if (postscript.length) return postscript.length === 1 ? postscript[0] : null;
    if (candidates.length === 1) {
      const record = candidates[0];
      if ([record.fullName, `${record.family} ${record.style}`].some((value) => normalizeFontAlias(value) === target) && normalizeFontAlias(record.family) !== target) return record;
    }
    if (!style) return resolveLocalFontFromLookup(name2, hostLookup);
    const styled = candidates.filter((record) => record.hostReference?.face.weight === style.weight && record.hostReference?.face.slant === style.slant);
    if (styled.length) return styled.length === 1 ? styled[0] : null;
    if (style.slant === "normal") return null;
    const alternate = candidates.filter((record) => record.hostReference?.face.weight === style.weight && record.hostReference?.face.slant === (style.slant === "italic" ? "oblique" : "italic"));
    return alternate.length === 1 ? alternate[0] : null;
  }

  // <stdin>
  var name = (value) => typeof value === "string" && value.trim().length > 0 && value.length <= 1024;
  var text = (value) => typeof value === "string" && value.length <= 1024;
  var key = (value) => value.replace(/\u0000/g, "").normalize("NFC").replace(/\s+/g, " ").trim().toLowerCase();
  function normalize(row) {
    if (!row || !["installed", "managed"].includes(row.source) || !name(row.id) || !name(row.family) || !name(row.fullName) || !text(row.postScriptName) || !text(row.style) || !Array.isArray(row.aliases) || row.aliases.length > 32 || !Number.isInteger(row.traits) || row.traits < 0 || row.traits > 4294967295) return null;
    const aliases = [...new Set(row.aliases.filter(name))];
    let weight = row.weight;
    let slant;
    if (row.source === "managed") {
      if (!Number.isInteger(weight) || weight < 1 || weight > 1e3) return null;
      slant = row.traits & 512 ? "oblique" : row.traits & 1 ? "italic" : "normal";
    } else {
      if (!name(row.style)) return null;
      const style = row.style.toLowerCase().replace(/[\s_-]/g, "");
      const base = style.replace(/italic|oblique/g, "") || "regular";
      const weights = {
        thin: 100,
        extralight: 200,
        ultralight: 200,
        light: 300,
        regular: 400,
        normal: 400,
        roman: 400,
        medium: 500,
        semibold: 600,
        demibold: 600,
        bold: 700,
        extrabold: 800,
        ultrabold: 800,
        black: 900,
        heavy: 900
      };
      weight = Object.prototype.hasOwnProperty.call(weights, base) ? weights[base] : null;
      if (!weight || base === "regular" && row.traits & 2) return null;
      slant = style.includes("oblique") ? "oblique" : row.traits & 1 || style.includes("italic") ? "italic" : "normal";
    }
    return {
      id: row.id,
      family: row.family,
      fullName: row.fullName,
      postscriptName: row.postScriptName,
      style: row.style,
      aliases,
      weight,
      slant
    };
  }
  function names(row) {
    return [row.family, row.fullName, row.postScriptName, ...Array.isArray(row.aliases) ? row.aliases : []].filter(name).map(key).filter(Boolean);
  }
  function select(rows) {
    const blocked = /* @__PURE__ */ new Set(), managed = [], installed = [], idCounts = /* @__PURE__ */ new Map();
    for (const row of rows) {
      idCounts.set(row.id, (idCounts.get(row.id) || 0) + 1);
      const face = normalize(row);
      if (row.source === "managed") {
        if (row.limitation || !face) names(row).forEach((n) => blocked.add(n));
        else managed.push({ row, face });
      } else if (face && !row.limitation) installed.push({ row, face });
    }
    const usable = ({ row, face }) => idCounts.get(face.id) === 1 && !names(row).some((n) => blocked.has(n));
    const selected = managed.filter(usable);
    const exact = /* @__PURE__ */ new Set(), styled = /* @__PURE__ */ new Set();
    for (const { row, face } of selected) {
      [row.postScriptName, row.fullName].filter(name).forEach((n) => exact.add(key(n)));
      names(row).forEach((n) => styled.add(JSON.stringify([n, face.weight, face.slant])));
    }
    const candidates = installed.filter(usable).filter(({ row, face }) => ![row.postScriptName, row.fullName].filter(name).some((n) => exact.has(key(n))) && !names(row).some((n) => styled.has(JSON.stringify([n, face.weight, face.slant]))));
    return [...selected, ...candidates].map(({ face }) => Object.freeze({ ...face, aliases: Object.freeze(face.aliases) }));
  }
  globalThis.resolveNativeFonts = async (input) => {
    globalThis.nativeFontResult = null;
    try {
      const value = JSON.parse(input);
      if (!name(value.identity) || !Array.isArray(value.faces) || value.faces.length > 25e3 || !Array.isArray(value.requests) || value.requests.length > 2048) throw Error("Invalid native catalog");
      const faces = select(value.faces);
      const provider = {
        getSnapshot: async () => ({ revision: value.identity, faces }),
        readFace: async () => {
          throw Error("Metadata-only matcher");
        },
        subscribe: () => () => {
        }
      };
      await setHostFontProvider(provider);
      await prepareHostFontCatalog();
      const selections = value.requests.map((request) => {
        if (!name(request.key) || !name(request.family) || ![400, 700].includes(request.weight) || !["normal", "italic"].includes(request.slant)) throw Error("Invalid native request");
        const face = resolveRendererLocalFont(request.family, request)?.hostReference?.face;
        const known = value.faces.some((row) => names(row).includes(key(request.family)));
        return face ? {
          key: request.key,
          status: "selected",
          id: face.id,
          postscriptName: face.postscriptName,
          weight: face.weight,
          slant: face.slant
        } : { key: request.key, status: known ? "unavailable" : "absent" };
      });
      globalThis.nativeFontResult = JSON.stringify({ identity: value.identity, selections });
    } catch {
      globalThis.nativeFontResult = JSON.stringify({ error: "invalidCatalog" });
    } finally {
      await setHostFontProvider(null);
    }
  };
})();
"""#
}
