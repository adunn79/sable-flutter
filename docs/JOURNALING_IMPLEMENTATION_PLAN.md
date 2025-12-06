# Sable Journaling Feature - Implementation Plan

## Goal

Build a premium journaling experience with AI Avatar companion integration. The Avatar enhances journaling through guided prompts, mood sensing, semantic search, and personalized reflections—all under strict user-controlled privacy.

## Technical Decisions

### Storage Strategy (BEST Approach)

| Layer | Technology | Purpose |
|-------|------------|---------|
| **Local** | **Hive** | Offline-first, fast read/write for large text, structured NoSQL |
| **Cloud** | **Firestore** | Real-time sync, cross-device, existing integration |
| **Vectors** | **Firebase Vector Search** | Semantic search, RAG pipeline, stays in Firebase ecosystem |

> [!NOTE]
> Hive is superior to SharedPreferences for journal data because it handles complex objects, large text blobs, and provides ~10x faster reads. The app already uses Firestore for cloud; Hive adds robust offline capability.

### Existing Assets (NO REBUILD)

These exist and will be **integrated, not recreated**:

- ✅ Avatar system (Sable/Kai/Echo) with animations
- ✅ Onboarding conversational flow
- ✅ Chat interface with AI (Gemini)
- ✅ Voice STT/TTS (speech_to_text, ElevenLabs)
- ✅ Riverpod state management
- ✅ go_router navigation
- ✅ Settings/privacy infrastructure

---

## Proposed Changes

### Phase 1: Foundation

---

#### [NEW] pubspec.yaml additions

```yaml
# Add to dependencies:
hive: ^2.2.3
hive_flutter: ^1.1.0
flutter_quill: ^9.4.0

# Add to dev_dependencies:
hive_generator: ^2.0.1
```

---

#### [NEW] lib/features/journal/models/journal_entry.dart

Journal entry data model with Hive adapter:

- `id`, `content` (rich text JSON), `plainText`, `timestamp`
- `bucketId`, `tags`, `moodScore`, `isPrivate`
- `location`, `weather`, `mediaUrls`
- `embeddingRef` (link to vector DB entry)

---

#### [NEW] lib/features/journal/models/journal_bucket.dart

Multiple journals (Personal, Work, Vault, etc.):

- `id`, `name`, `icon`, `color`
- `isVault` (forces all entries private)
- `avatarAccessDefault` (default eye toggle state)

---

#### [NEW] lib/features/journal/services/journal_storage_service.dart

Offline-first storage with sync:

- Hive box for local entries
- Firestore collection for cloud sync
- Conflict resolution (last-write-wins with timestamps)
- Auto-sync on connectivity change

---

#### [NEW] lib/features/journal/screens/journal_editor_screen.dart

Rich text editor with:

- flutter_quill editor widget
- Media attachment toolbar (camera, gallery, audio)
- "Eye" privacy toggle (is_private flag)
- Tag input chips
- Auto-metadata capture on save
- "Spark" prompt button (floating)

---

#### [NEW] lib/features/journal/screens/journal_timeline_screen.dart

Entry list view:

- Reverse-chronological timeline
- Search/filter by keyword, tag, date
- Preview cards with mood indicator

---

#### [NEW] lib/features/journal/screens/journal_calendar_screen.dart

Calendar mood visualization:

- Monthly grid with Avatar face icons per day
- Mood score mapped to expressions (1=sad, 5=happy)
- Tap day to view entries

---

### Phase 2: Avatar Integration

---

#### [MODIFY] lib/src/shared/app_shell.dart

- Add global Avatar overlay widget
- Persist across all screens (Stack at root)
- State: idle, observing, blind, active (expanded)

---

#### [NEW] lib/features/journal/widgets/avatar_journal_overlay.dart

Journal-aware avatar overlay:

- Reads current entry's `isPrivate` flag
- Visual state changes (eye open/closed)
- Half-sheet chat expansion
- "Spark" button integration

---

#### [MODIFY] lib/src/pages/chat/chat_page.dart

- Add "Talk to Journal" mode
- Route voice dictation to journal editor
- Debrief trigger on entry save

---

#### [NEW] lib/features/journal/screens/journal_onboarding_screen.dart

Conversational setup for journal Avatar access:

- "Which journals should I access?"
- Per-bucket privacy defaults
- Saves to OnboardingStateService

---

### Phase 3: AI Intelligence

---

#### [NEW] Firebase Cloud Functions (functions/src/index.ts)

Vector pipeline triggers:

- `onEntryCreate`: If not private → embed via Vertex AI → store vector
- `onEntryUpdate`: Re-embed if content changed and not private
- `onEntryDelete`: Remove vector
- `onPrivacyChange`: Add/remove from vector index

---

#### [NEW] lib/features/journal/services/journal_ai_service.dart

RAG and sentiment analysis:

- `analyzeSentiment(text)` → mood_score 1-5
- `generatePrompt(context)` → personalized Spark prompt
- `semanticSearch(query)` → retrieve relevant entries
- `generateDebrief(entry)` → empathetic follow-up

---

#### [MODIFY] lib/features/onboarding/services/onboarding_state_service.dart

- Add journal-specific preferences
- `journalAvatarBuckets` (which buckets Avatar can see)
- `journalReminderTime`, `journalStreakCount`

---

### Phase 4: Privacy & Polish

---

#### [NEW] lib/features/journal/screens/knowledge_center_screen.dart

Avatar memory management:

- List extracted facts/topics
- "Forget" button per item (removes from vector DB)
- Clear all memory option

---

#### [NEW] lib/features/journal/screens/private_repository_screen.dart

Share-to-Sable repository:

- External context items (emails, articles, photos)
- View/delete shared items
- Embedded in vector DB for RAG

---

#### [NEW] lib/features/journal/services/journal_export_service.dart

Export functionality:

- Single entry as PDF/Markdown
- Full journal as JSON backup
- Uses existing `printing` and `pdf` packages

---

## User Review Required

> [!IMPORTANT]
> **Firebase Vector Search Setup**: This requires enabling the Firebase Vector Search extension in your Firebase console and setting up a Vertex AI service account. I'll provide setup instructions during implementation.

> [!WARNING]
> **Cloud Function Deployment**: The RAG pipeline requires deploying Firebase Cloud Functions. This involves `firebase deploy --only functions`. Do you have Firebase CLI set up?

---

## Verification Plan

### Automated Tests

Since this is a Flutter project, I'll test incrementally:

```bash
# Run existing tests (identify baseline)
flutter test

# Run with coverage after changes
flutter test --coverage
```

### Manual Verification (Phase-by-Phase)

**Phase 1 - Foundation:**

1. Open app → Navigate to new Journal screen
2. Create new entry with text + photo → Verify saves
3. Toggle "Eye" closed → Check UI reflects private
4. Close app, reopen → Verify entry persists (Hive)
5. Check Firestore console → Verify sync

**Phase 2 - Avatar Integration:**

1. Open journal → See Avatar overlay
2. Mark entry private → Avatar eyes should close
3. Tap Avatar → Chat panel expands
4. Tap Spark → Get a prompt suggestion
5. Use voice dictation → Text appears in editor

**Phase 3 - AI Intelligence:**

1. Save non-private entry → Check Firestore Vector Search index
2. Ask Avatar "When did I mention X?" → Get correct answer
3. Save sad-tone entry → Verify mood_score is low
4. Check calendar → See sad face icon on that day

**Phase 4 - Privacy:**

1. Open Knowledge Center → See indexed topics
2. Tap Forget → Verify removed from vector index
3. Export entry as PDF → Verify file generates

---

## File Structure Summary

```
lib/features/journal/
├── models/
│   ├── journal_entry.dart
│   ├── journal_entry.g.dart (generated)
│   └── journal_bucket.dart
├── services/
│   ├── journal_storage_service.dart
│   ├── journal_ai_service.dart
│   └── journal_export_service.dart
├── screens/
│   ├── journal_editor_screen.dart
│   ├── journal_timeline_screen.dart
│   ├── journal_calendar_screen.dart
│   ├── journal_onboarding_screen.dart
│   ├── knowledge_center_screen.dart
│   └── private_repository_screen.dart
├── widgets/
│   ├── avatar_journal_overlay.dart
│   ├── mood_calendar_widget.dart
│   ├── entry_preview_card.dart
│   └── privacy_eye_toggle.dart
└── providers/
    └── journal_providers.dart
```

---

## Estimated Timeline

| Phase | Focus | Duration |
|-------|-------|----------|
| **1** | Foundation (Storage, Editor, Views) | 3-4 days |
| **2** | Avatar Integration (Overlay, Dictation) | 2-3 days |
| **3** | AI Intelligence (Vector DB, RAG, Mood) | 3-4 days |
| **4** | Privacy & Polish (Export, Knowledge Center) | 2-3 days |

**Total: ~2 weeks for complete implementation**
