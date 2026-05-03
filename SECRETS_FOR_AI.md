# SECRETS - UTOPIA App

## Firebase Configuration (lib/firebase_options.dart)
```
apiKey: "AIzaSyBGslt8X1GGuIsqlIhwSxEi7iCNf-N6DN4"
appId: "1:402670858978:android:200c4504814ccd9ffea4bb"
messagingSenderId: "402670858978"
projectId: "utopia-app-33cf8"
databaseURL: "https://utopia-app-33cf8-default-rtdb.asia-southeast1.firebasedatabase.app"
storageBucket: "utopia-app-33cf8.firebasestorage.app"
```

## Google Sign-In (lib/main.dart)
```
serverClientId: "402670858978-94eqn0qvvrtv59ijne3hn1g5flr4ahve.apps.googleusercontent.com"
```

## Supabase Configuration (stored in Firestore config/supabase document)
```
url: "[SUPABASE_URL]"
anonKey: "[SUPABASE_ANON_KEY]"
```

## AI Service API Keys (stored in Firestore)
### config/iaa document:
```
providers: [
  {
    "id": "[PROVIDER_ID]",
    "label": "[PROVIDER_LABEL]",
    "endpoint": "[ENDPOINT_URL]",
    "models": ["[MODEL_1]", "[MODEL_2]"],
    "apiKeys": ["[API_KEY_1]", "[API_KEY_2]"]
  }
]
```

### config/grok document (legacy):
```
apiKey: "[GROQ_API_KEY]"
endpoint: "https://api.groq.com/openai/v1/chat/completions"
model: "llama-3.3-70b-versatile"
```

### config/gemini document (legacy):
```
apiKey: "[GEMINI_API_KEY]"
```
