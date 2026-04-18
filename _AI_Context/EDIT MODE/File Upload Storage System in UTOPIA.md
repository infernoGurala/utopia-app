## Overview

UTOPIA allows users to upload files (PDFs, documents, etc.) inside the Edit Mode. These files are hosted on **Firebase Storage** and the download links are embedded into the markdown content of the note, which is then pushed to GitHub.

The storage system uses a **multi-bucket architecture** — multiple Firebase projects are used as storage buckets, each on the free Spark plan. When one bucket fills up, the app automatically switches to the next one. Old links from filled buckets remain permanently valid because those Firebase projects are never deleted.

---

## Why Multi-Bucket

- Firebase Storage free (Spark) plan gives **5GB per project**
- The app may serve an entire university — files will accumulate rapidly
- When a bucket is full, Firebase blocks new uploads but **never deletes existing files or invalidates existing URLs**
- So the strategy is: use one bucket until full, switch to a new one, repeat
- The main Firebase project (with Firestore, Auth, etc.) is **never touched or migrated**. Only the active Storage bucket changes.

---

## Project Structure

There are two types of Firebase projects in this system:

### 1. Main Project (permanent)

- Holds: Firestore database, Firebase Auth, all app logic
- Also holds a special Firestore document called the **Storage Config**
- This project is never replaced or migrated

### 2. Storage Projects (storage-only)

- These are separate Firebase projects created purely for file storage
- They contain only Firebase Storage — no Firestore, no Auth
- Named sequentially for clarity: `utopia-storage-1`, `utopia-storage-2`, etc.
- Each has its own `google-services.json` and Storage bucket URL

---

## Storage Config (Firestore Document)

Inside the main Firebase project's Firestore, there is a document at:

```
Collection: app_config
Document:   storage_config
```

This document holds the following fields:

|Field|Type|Description|
|---|---|---|
|`active_bucket_id`|String|Identifier of the currently active storage project (e.g., `"storage_1"`)|
|`bucket_url`|String|The Firebase Storage bucket URL of the active project (e.g., `"gs://utopia-storage-1.appspot.com"`)|

When the active bucket fills up and it is time to switch, **only this one Firestore document is updated**. The app reads this config before every upload and always uploads to the correct bucket. No code changes, no app update, no user disruption.

---

## Upload Flow (Step by Step)

This is the complete sequence of events when a user uploads a file in Edit Mode:

### Step 1 — User selects a file

- The user taps the Upload option inside Edit Mode
- A file picker opens (limited to files under 20MB)
- If the file exceeds 20MB, a warning is shown and the operation is cancelled

### Step 2 — User provides a display name

- After selecting the file, the user is prompted to enter a display name
- This is the name shown in the note (not the actual filename)

### Step 3 — App reads Storage Config

- Before uploading, the app reads the `storage_config` document from Firestore
- It extracts the `bucket_url` of the currently active storage project
- This tells the app _where_ to upload

### Step 4 — File is uploaded to Firebase Storage

- The file is uploaded to the active bucket using the Firebase Storage SDK
- The upload path inside the bucket follows this structure:
    
    ```
    uploads/{university_id}/{uploader_uid}/{timestamp}_{original_filename}
    ```
    
- This ensures no filename collisions across users

### Step 5 — Download URL is retrieved

- After a successful upload, Firebase returns a permanent public download URL
- This URL points directly to the file and is valid indefinitely as long as the project exists

### Step 6 — Markdown is generated

- The app generates a markdown block using the download URL and the display name the user provided
- The format used is the standard Files section format in UTOPIA notes (see `Upload a file.md`)

### Step 7 — Block is inserted into the note

- The generated markdown block is inserted into the current note in Edit Mode
- It appears as a draggable block like all other blocks

### Step 8 — Note is saved / pushed to GitHub

- When the user saves the note, the full markdown (including the file link) is pushed to GitHub as usual
- The file itself lives on Firebase Storage; the GitHub note only contains the URL

---

## Switching to a New Bucket (Admin Action)

When the active bucket approaches 5GB, the following steps are taken manually by the developer (John):

1. Create a new Firebase project (e.g., `utopia-storage-2`)
2. Enable Firebase Storage in the new project
3. Set Storage rules to allow public reads and authenticated writes
4. Register the new project's `google-services.json` in the Flutter app (all bucket credentials should be pre-registered in the app for all known future buckets)
5. Go to Firestore in the main project
6. Update the `storage_config` document:
    - Change `active_bucket_id` to `"storage_2"`
    - Change `bucket_url` to the new bucket's URL
7. Done — the app now uploads to the new bucket automatically

**Old bucket stays alive.** All existing download URLs from bucket 1 continue to work forever. No migration needed.

---

## Firebase Storage SDK — Multi-Bucket Note

By default, the Firebase Storage SDK in Flutter connects to the default bucket of the currently initialized Firebase app. To upload to a different project's bucket, the app must initialize a **secondary Firebase app** using that project's credentials.

All storage project credentials (google-services configs) should be bundled in the app at build time. The app selects which secondary Firebase app to use for storage based on the `active_bucket_id` from the Firestore config.

Each secondary Firebase app is initialized once and reused. The app should handle initialization gracefully — if a secondary app is already initialized, it should not be initialized again.

---

## Storage Rules (for each Storage Project)

Each storage project should have the following Firebase Storage rules:

- **Public read**: Anyone with the download URL can access the file (needed for offline viewing and downloads without login)
- **Authenticated write**: Only signed-in users can upload files (prevents abuse)

---

## File Block in the Note (UI Behaviour)

Once a file is uploaded and the block is inserted into the note:

- The block displays the user-given display name
- It shows a download/view button
- Tapping the button opens the file using the device's default viewer or downloads it
- The block can be repositioned like any other block in Edit Mode
- The block can be deleted with undo support (but undo is not available after the note is pushed to GitHub)

---

## Key Constraints Summary

|Constraint|Value|
|---|---|
|Max file size|20MB|
|Storage per bucket|5GB (Firebase free tier)|
|Download bandwidth per bucket|1GB/day (Firebase free tier)|
|File URL lifetime|Permanent (as long as project exists)|
|Switching cost on bucket full|Update 1 Firestore document only|
|Main project affected on switch|No|
|Old links broken on switch|Never|