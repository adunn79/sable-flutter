# Sable Journaling Feature - Task Breakdown

## Phase 1: Foundation & Core Journal (Week 1)

### 1A: Project Setup & Dependencies
- [ ] Add Hive + hive_flutter for offline-first storage
- [ ] Add flutter_quill for rich text editing
- [ ] Create `lib/features/journal/` directory structure
- [ ] Set up Hive adapters and initialization

### 1B: Journal Entry Model & Storage
- [ ] Create JournalEntry model (content, timestamp, mood_score, is_private, tags, etc.)
- [ ] Create JournalBucket model (multiple journals)
- [ ] Implement JournalStorageService (Hive local + Firestore sync)
- [ ] Implement offline-first sync logic

### 1C: Journal Editor Screen
- [ ] Build rich text editor with flutter_quill
- [ ] Add media attachment support (photos from gallery/camera)
- [ ] Implement auto-metadata capture (location, weather)
- [ ] Add "Eye" privacy toggle (is_private flag)
- [ ] Add tag input/management

### 1D: Timeline & Calendar Views
- [ ] Create journal timeline screen (reverse-chronological)
- [ ] Create calendar view with mood face icons
- [ ] Implement day-tap to view entries
- [ ] Add basic search/filter by tag

---

## Phase 2: Avatar Integration & UI (Week 2)

### 2A: Avatar Overlay Enhancement
- [ ] Extend existing avatar to global overlay (persistent across screens)
- [ ] Add "Observing" (eye open) vs "Blind" (eye closed) visual states
- [ ] Implement half-sheet chat panel expansion
- [ ] Add "Spark" button in journal editor

### 2B: Conversational Journal Onboarding
- [ ] Create journal-specific onboarding flow
- [ ] Ask: "Which journals should I have access to?"
- [ ] Save default privacy preferences per bucket

### 2C: Voice Dictation for Journaling
- [ ] Connect existing STT to journal editor
- [ ] Real-time transcription display
- [ ] Avatar "listening" animation state
- [ ] Post-dictation confirmation prompt

### 2D: Debrief Trigger
- [ ] On entry save, trigger Avatar response
- [ ] Generate empathetic comment or follow-up question
- [ ] Display in expandable Avatar panel

---

## Phase 3: AI Intelligence & RAG (Week 3)

### 3A: Vector Database Setup
- [ ] Set up Firebase Vector Search Extension
- [ ] Create Cloud Function for embedding generation
- [ ] Index only non-private entries (is_private == false)
- [ ] Implement delete/update triggers

### 3B: Mood Inference
- [ ] Implement sentiment analysis on entry save
- [ ] Calculate mood_score (1-5)
- [ ] Update calendar mood icons
- [ ] Avatar verbal feedback based on mood

### 3C: Semantic Search
- [ ] Implement "When did I last mention X?" queries
- [ ] Vector search retrieval pipeline
- [ ] Avatar summarizes findings
- [ ] Link to relevant entries

### 3D: Personalized Prompts (RAG)
- [ ] Connect "Spark" button to RAG-based prompt generation
- [ ] Anniversary prompts ("One year ago...")
- [ ] Goal/pattern reminders
- [ ] Mood-based coaching (breathing exercises)

---

## Phase 4: Privacy & Polish (Week 4)

### 4A: Privacy Architecture
- [ ] Implement "Knowledge Center" screen
- [ ] List all Avatar-accessible facts
- [ ] "Forget" button per item
- [ ] "Incognito Vault" bucket (always private)

### 4B: Private Sharing Repository
- [ ] Share sheet integration ("Share with Sable")
- [ ] Context items stored in vector DB
- [ ] View/delete shared items

### 4C: Streaks, Reminders & Flashbacks
- [ ] Daily reminder notifications
- [ ] Streak counter with Avatar celebration
- [ ] "On This Day" feature with Avatar commentary

### 4D: Export & Polish
- [ ] Export entry as PDF/JSON
- [ ] Export full journal backup
- [ ] UI polish and animations
- [ ] Final testing

---

## Current Status
- [/] **Phase 1A**: Planning implementation approach
