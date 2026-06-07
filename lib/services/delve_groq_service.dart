import '../services/ai_service.dart';

class GroqService {
  Future<bool> validateMeaning(String word, String expected, String input) async {
    final prompt = '''
You are an evaluator. 
Word: $word
Expected meaning conceptually: $expected
User's submitted meaning: $input

Does the user's meaning correctly capture the essence of the expected meaning? 
Reply strictly with "YES" or "NO".
''';
    try {
      final response = await AIService.sendCustomMessage(
        messages: [
          {'role': 'user', 'content': prompt}
        ],
        maxTokens: 10,
      );
      return response.trim().toUpperCase().contains('YES');
    } catch (e) {
      // fallback
      return input.trim().toLowerCase() == expected.trim().toLowerCase();
    }
  }

  Future<String?> generateMeaning(String word) async {
    final prompt = '''
You are a dictionary assistant that explains words simply.
Provide a single, short, and simple sentence explaining the meaning of the word "$word".
Use only common, everyday, and general words. Do not use any heavy, complex, or unfamiliar words in the explanation.
Keep it under 15 words. Only return the actual meaning sentence. Do not wrap in quotes or add extra explanation.
''';
    try {
      final response = await AIService.sendCustomMessage(
        messages: [
          {'role': 'user', 'content': prompt}
        ],
        maxTokens: 50,
      );
      return response.trim();
    } catch (e) {
      return null;
    }
  }

  Future<String?> fetchPartOfSpeech(String word) async {
    final prompt = '''
You are a linguistic analyzer. What is the primary part of speech for the word "$word"?
Return strictly ONE of these words: noun, verb, adjective, adverb, pronoun, preposition, conjunction, interjection.
Do not include any punctuation, explanation, or extra text.
''';
    try {
      final response = await AIService.sendCustomMessage(
        messages: [
          {'role': 'user', 'content': prompt}
        ],
        maxTokens: 10,
      );
      final answer = response.trim().toLowerCase();
      if (answer.contains('noun')) return 'noun';
      if (answer.contains('verb')) return 'verb';
      if (answer.contains('adjective')) return 'adjective';
      if (answer.contains('adverb')) return 'adverb';
      if (answer.contains('pronoun')) return 'pronoun';
      if (answer.contains('preposition')) return 'preposition';
      if (answer.contains('conjunction')) return 'conjunction';
      if (answer.contains('interjection')) return 'interjection';
      return null;
    } catch (e) {
      return null;
    }
  }
}
