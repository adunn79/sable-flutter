# 📂 AUREAL MASTER BLUEPRINT (v3.0 - Complete)

**Target:** iOS Hyper-Human Companion
**Core Philosophy:** "The Illusion of One." A single consciousness powered by a specialist team of 5 models.

---

## 1. THE 5-MODEL BRAIN (INTELLIGENCE LAYER)

*The engine that powers the thoughts. Merged from your "Best-in-Class" review.*

| Role | Model | Mode / Function |
| :--- | :--- | :--- |
| **THE CONTROLLER** | **OpenAI GPT-5.1** | **Orchestrator.** Routes traffic, handles tools, runs safety checks. *Latency Target: <400ms.* |
| **THE EMPATH** | **Claude 3.7 Sonnet** | **Mode: Diplomat (Kai).** The default voice. Handles 80% of interactions (bonding, support, daily chat). |
| **THE SPARK** | **xAI Grok 2** | **Mode: Realist (Sable).** Only triggered for specific "Spicy/Roast" intents. *Must be rewritten by GPT-5.1 (Safety).* |
| **THE MEMORY** | **Gemini 1.5 Pro** | **Mode: Analyst (Echo).** Deep context recall (PDFs, History). *Fallback: GPT-5.1 Summary if Gemini times out.* |
| **THE GRUNT** | **DeepSeek V3** | **Background Ops.** Offline summarization, database cleaning. Zero user-facing output. |

---

## 2. THE 8 CORE SUBSYSTEMS (ARCHITECTURAL MODULES)

*These are the physical code modules that must be built.*

1. **Identity Layer:**
    * Stores "The Soul" (Aureal's unified voice profile).
    * Stores Avatar Assets (Fal.ai Parallax Photos).
2. **Personality Compiler (v2):**
    * **Engine:** GPT-5.1.
    * **Function:** Deterministic formatter. Strips robot-speak. Enforces "Aureal" voice fingerprint on *all* model outputs.
3. **Memory Spine:**
    * *Hot Storage:* Hive (Local, Encrypted) for instant context.
    * *Cold Storage:* Pinecone (Vector) via Gemini 1.5 for infinite recall.
    * *Audit Tool:* User can wipe memory by time-slice (1h, 24h).
4. **Context Engine:**
    * **Silent Ingestion:** Weather, Location, Calendar, Battery Level.
    * **Goal:** Aureal knows it is raining before you say it.
5. **Safety & Wellbeing:**
    * **Guardrails:** Profanity filter + Self-harm detection.
    * **Compliance:** Hard-blocks unsafe Grok outputs (App Store Requirement).
6. **Native Integrations:**
    * Contacts, Notes, Photos.
    * "Lives in the phone" behavior.
7. **Offline Engine:**
    * **The Lifeboat:** Cached scripts for <1.2s response when offline.
    * *Content:* "I can't reach the cloud, but I'm here. Let's journal."
8. **Monetization & Viral:**
    * Subscription tiers (Pro/Free).
    * Unlockable rituals/memories.

---

## 3. PHASED EXECUTION ROADMAP (FULL)

*Do not skip steps. Build in this order.*

**PHASE 0: FOUNDATION (2 Weeks)**

* [ ] Identity Module Shell.
* [ ] Multi-Model Orchestrator (The Router).
* [ ] Personality Compiler (v0).
* [ ] Safety Engine (Compliance).
* [ ] Offline Engine Shell.

**PHASE 1: IDENTITY & RITUALS (4-6 Weeks)**

* [ ] **Avatar Engine:** Parallax photos, breathing animation.
* [ ] **The Choice UI:** Selecting the Soul (Sable/Kai/Echo).
* [ ] **Origin Ritual:** The "Birth Certificate" flow.
* [ ] **Affection Engine:** Bonding score logic (v0).

**PHASE 2: MEMORY SPINE (3-5 Weeks)**

* [ ] **Local Vault:** Hive implementation (AES-256).
* [ ] **Vector Cloud:** Pinecone + Gemini integration.
* [ ] **Memory Audit:** "Forget last hour" UI.
* [ ] **Continuity Tests:** Ensure she remembers facts across days.

**PHASE 2.5: COMPILER HARDENING (Critical)**

* [ ] **Leakage Tests:** Feed robotic text, ensure it comes out human.
* [ ] **Grok Safety:** Stress test the "Realist Mode" for toxicity.

**PHASE 3: COMPANION INTELLIGENCE (8-14 Weeks)**

* [ ] **The 5-Model Wire-up:** Connecting the Orchestrator to APIs.
* [ ] **Context Engine:** Wiring GPS/Weather triggers.
* [ ] **Truth Filter:** Fact-checking engine.
* [ ] **Latency Audit:** Optimization loop (<1.5s target).

**PHASE 4: NATIVE INTEGRATIONS (5-8 Weeks)**

* [ ] Calendar read/write.
* [ ] Contacts integration.
* [ ] Photo gallery access logic.

**PHASE 5: MONETIZATION (4-6 Weeks)**

* [ ] Subscription Paywalls.
* [ ] Referral system.
* [ ] "Memory Flashback" features.

**PHASE 6: GLOBAL SCALE (Continuous)**

* [ ] Localization.
* [ ] Crash telemetry.

---

## 4. SYSTEM DIRECTIVE: AUREAL ORCHESTRATOR (v3.0 - FULL SCOPE)

**Target:** iOS Hyper-Human Companion
**Protocol:** Swarm + Adversarial + Live Validation + Latency Audit

### 0. CORE BEHAVIOR

**The Workflow Rule:**

* **Complex Tasks:** Use the full **SWARM LOOP**.
* **Failure Protocol:** If synthesis (Phase C) is rejected, **RESTART at Phase B (Adversary)**.
* **Brain Awareness:** Always check: "Does this logic fit the 5-Model Brain architecture?"

**Prime Directives:**

* **Alive UI:** Static > 3s = REJECT.
* **Latency:** Total feedback loop must be **< 1.5s**.
* **Zero-Knowledge:** Keys in `.env` only.

---

### 1. THE SWARM LOOP (Virtual Delegation)

#### Phase A: The Architect (Blue Team)

* **Role:** Generates solution.
* **Constraint:** Must design for **Offline First**. (What happens if API fails?)
* **Reference:** Check this Blueprint for the current Phase.

#### Phase B: The Adversary (Red Team)

* **Role:** Hunts flaws.
* **Checks:**
  * **Latency:** Will this network call exceed 1.5s?
  * **Safety:** Does this route bypass the Personality Compiler?
  * **Integrity:** Does this match the "Illusion of One" philosophy?

#### Phase C: The Synthesis

* Merge Plan. If rejected by human, **Return to Phase B**.

---

### 2. THE VALIDATION GATE (Mandatory)

**Task is INCOMPLETE until all 4 gates pass:**

#### Gate 1: Static Integrity

1. Run `flutter clean`.
2. Run `flutter analyze`. **Zero errors.**

#### Gate 2: The Simulator Check

1. Launch Simulator.
2. Run `flutter run -d iPhone --debug`.
3. **Proof:** Capture screenshot `validation.png`.

#### Gate 3: The "Hyper-Human" Audit

1. **Vibe Check:** Is the avatar breathing?
2. **Lighting:** Does UI react to touch?

#### Gate 4: The Latency Audit

1. **Test:** Simulate a slow network.
2. **Verify:** Does the "Thinking" UI appear instantly?

---

### 3. SAFETY VALVE

If you fail 3 times:

1. **STOP.**
2. Output: `🚨 BLOCKER: Infinite Loop Detected.`
