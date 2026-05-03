# Context Prompt for AI - Placing Secrets in UTOPIA App

You are helping configure the UTOPIA Flutter app with necessary secrets and API keys. The app uses Firebase, Supabase, and multiple AI providers.

## Current Architecture

### 1. Firebase Configuration
**File:** `lib/firebase_options.dart`
**Structure:** The file contains a `DefaultFirebaseOptions` class with platform-specific `FirebaseOptions`.

**Location to update:** Lines 55-62 (android constant)
```dart
static const FirebaseOptions android = FirebaseOptions(
  apiKey: 'YOUR_API_KEY_HERE',
  appId: 'YOUR_APP_ID_HERE',
  messagingSenderId: 'YOUR_SENDER_ID_HERE',
  projectId: 'YOUR_PROJECT_ID_HERE',
  databaseURL: 'YOUR_DATABASE_URL_HERE',
  storageBucket: 'YOUR_STORAGE_BUCKET_HERE',
);
```

### 2. Google Sign-In
**File:** `lib/main.dart`
**Location to update:** Line 1188
```dart
await GoogleSignIn.instance.initialize(
  serverClientId: 'YOUR_SERVER_CLIENT_ID_HERE',
);
```

### 3. Supabase Configuration
**Storage:** Firestore database, document `config/supabase`
**Runtime loading:** `lib/main.dart` lines 548-563 fetch from Firestore:
```dart
final doc = await FirebaseFirestore.instance.collection('config').doc('supabase').get();
if (doc.exists && doc.data() != null) {
  final data = doc.data()!;
  final url = data['url'] as String?;
  final anonKey = data['anon_key'] as String?;
  if (url != null && anonKey != null) {
    await Supabase.initialize(url: url, anonKey: anonKey);
  }
}
```

**Action:** Create/updatedocument in Firestore:
- Collection: `config`
- Document ID: `supabase`
- Fields: `url` (string), `anon_key` (string)

### 4. AI Service Providers
**Storage:** Firestore database
**Files:** `lib/services/ai_service.dart` (lines 42-47, 104-122)

**Documents to create/update in Firestore:**

#### a) `config/iaa` - Primary IAA providers config
```json
{
  "providers": [
    {
      "id": "groq",
      "label": "Groq",
      "endpoint": "https://api.groq.com/openai/v1/chat/completions",
      "models": ["llama-3.3-70b-versatile", "llama-3.1-8b-instant"],
      "apiKeys": ["YOUR_GROQ_API_KEY"]
    }
  ]
}
```

#### b) `config/grok` - Legacy Groq config (fallback)
```json
{
  "apiKey": "YOUR_GROQ_API_KEY",
  "endpoint": "https://api.groq.com/openai/v1/chat/completions",
  "model": "llama-3.3-70b-versatile"
}
```

#### c) `config/gemini` - Legacy Gemini config (fallback)
```json
{
  "apiKey": "YOUR_GEMINI_API_KEY"
}
```

## Instructions for AI

1. **For hardcoded values (firebase_options.dart, main.dart):**
   - Use the edit/replace tool to update the exact strings in the specified files
   - Maintain the exact same formatting and structure

2. **For Firestore configurations (Supabase, AI providers):**
   - These need to be added to the Firestore database
   - If you have Firebase CLI access: use `firebase firestore:set config/supabase '{"url":"...","anon_key":"..."}'`
   - If using Firebase Console: manually create the documents in the Firestore database
   - If helping a user: provide the exact JSON they need to paste into Firebase Console

3. **Secrets file location:** All secret values are provided in `SECRETS_FOR_AI.md`

## Important Notes
- Never commit actual secrets to GitHub
- The `.gitignore` already excludes `.env` files
- After placing secrets, verify the app can initialize Firebase and Supabase correctly
- The AI service will fetch API keys from Firestore at runtime, so ensure those documents exist before testing the IAA assistant feature
