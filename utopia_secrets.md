# UTOPIA App Complete Secrets & Configuration Guide

This file contains ALL the necessary secrets, API keys, and configurations needed to clone the `utopia-app` repository and run it locally.

## 1. Firebase Configuration

The core backend uses Firebase (Auth, Firestore, Realtime Database, Storage).

**File:** `lib/firebase_options.dart` (You may need to regenerate this file using FlutterFire CLI, or just use these values)
```dart
    apiKey: 'AIzaSyBGslt8X1GGuIsqlIhwSxEi7iCNf-N6DN4',
    appId: '1:402670858978:android:200c4504814ccd9ffea4bb',
    messagingSenderId: '402670858978',
    projectId: 'utopia-app-33cf8',
    databaseURL: 'https://utopia-app-33cf8-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'utopia-app-33cf8.firebasestorage.app',
```

## 2. Google Sign-In Authentication

For Google Sign-In to work on Android/iOS, you need the OAuth Client ID.

**Files:** `lib/main.dart` and `lib/screens/profile_screen.dart`
```dart
serverClientId: '402670858978-94eqn0qvvrtv59ijne3hn1g5flr4ahve.apps.googleusercontent.com'
```

## 3. Database Secrets (Supabase)

Supabase is used as an auxiliary backend. These keys are fetched dynamically from Firestore, so you will need to add them to your Firestore database under the `config/supabase` document.

**Firestore Path:** `config/supabase`
```json
{
  "url": "[SUPABASE_URL]",
  "anonKey": "[SUPABASE_ANON_KEY]"
}
```

## 4. AI Service Integrations

Utopia uses AI services for the "Delve" vocabulary and parsing features. These are also fetched from Firestore dynamically.

**Firestore Path:** `config/iaa`
```json
{
  "providers": [
    {
      "id": "[PROVIDER_ID]",
      "label": "[PROVIDER_LABEL]",
      "endpoint": "[ENDPOINT_URL]",
      "models": ["[MODEL_1]", "[MODEL_2]"],
      "apiKeys": ["[API_KEY_1]", "[API_KEY_2]"]
    }
  ]
}
```

**Firestore Path (Legacy Grok/Llama):** `config/grok`
```json
{
  "apiKey": "[GROQ_API_KEY]",
  "endpoint": "https://api.groq.com/openai/v1/chat/completions",
  "model": "llama-3.3-70b-versatile"
}
```

**Firestore Path (Legacy Gemini):** `config/gemini`
```json
{
  "apiKey": "[GEMINI_API_KEY]"
}
```

## Setup Instructions
1. `git clone` the repository
2. Run `flutter pub get`
3. Setup your own Firebase project (if you don't have access to the production `utopia-app-33cf8` project)
4. Add the above JSON structures to your Firestore database under the `config` collection to enable AI and Supabase features.
