import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ChatEmojiCategory {
  const ChatEmojiCategory({required this.key, required this.label, required this.icon});
  final String key;
  final String label;
  final IconData icon;
}

class ChatEmoji {
  const ChatEmoji({required this.token, required this.assetPath, required this.categoryKey});
  final String token;
  final String assetPath;
  final String categoryKey;
}

class ChatEmojiCatalog {
  static final RegExp tokenPattern = RegExp(r':[a-z0-9_]+:');
  static const legacyAliases = {
    ':beaming_face:': ':beaming_face_with_smiling_eyes:',
    ':face_with_symbols_on_mouth:': ':face_with_symbol_on_mouth:',
  };

  static const categories = [
    ChatEmojiCategory(key: 'smileys', label: 'Smileys', icon: Icons.emoji_emotions_outlined),
    ChatEmojiCategory(key: 'people', label: 'People', icon: Icons.waving_hand_rounded),
    ChatEmojiCategory(key: 'animals_nature', label: 'Animals', icon: Icons.pets_outlined),
    ChatEmojiCategory(key: 'food_drink', label: 'Food', icon: Icons.fastfood_outlined),
    ChatEmojiCategory(key: 'travel_places', label: 'Travel', icon: Icons.directions_car_filled_outlined),
    ChatEmojiCategory(key: 'objects', label: 'Objects', icon: Icons.lightbulb_outline_rounded),
    ChatEmojiCategory(key: 'symbols', label: 'Symbols', icon: Icons.favorite_border_rounded),
  ];

  static const emojis = [
    ChatEmoji(token: ':grinning_face:', assetPath: 'assets/chat_emojis/Grinning-Face--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':grinning_face_with_big_eyes:', assetPath: 'assets/chat_emojis/Grinning-Face-With-Big-Eyes--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':grinning_face_with_smiling_eyes:', assetPath: 'assets/chat_emojis/Grinning-Face-With-Smiling-Eyes--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':beaming_face_with_smiling_eyes:', assetPath: 'assets/chat_emojis/Beaming-Face-With-Smiling-Eyes--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':slightly_smiling_face:', assetPath: 'assets/chat_emojis/Slightly-Smiling-Face--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':smiling_face:', assetPath: 'assets/chat_emojis/Smiling-Face--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':smiling_face_with_smiling_eyes:', assetPath: 'assets/chat_emojis/Smiling-Face-With-Smiling-Eyes--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':smiling_face_with_sunglasses:', assetPath: 'assets/chat_emojis/Smiling-Face-With-Sunglasses--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':winking_face:', assetPath: 'assets/chat_emojis/Winking-Face--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':winking_face_with_tongue:', assetPath: 'assets/chat_emojis/Winking-Face-With-Tongue--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':thinking_face_a:', assetPath: 'assets/chat_emojis/Thinking-Face-A--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':thinking_face_b:', assetPath: 'assets/chat_emojis/Thinking-Face-B--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':neutral_face:', assetPath: 'assets/chat_emojis/Neutral-Face--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':face_with_raised_eyebrow:', assetPath: 'assets/chat_emojis/Face-With-Raised-Eyebrow--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':face_with_rolling_eyes:', assetPath: 'assets/chat_emojis/Face-With-Rolling-Eyes--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':relieved_face:', assetPath: 'assets/chat_emojis/Relieved-Face--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':anguished_face:', assetPath: 'assets/chat_emojis/Anguished-Face--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':anxious_face_with_sweat:', assetPath: 'assets/chat_emojis/Anxious-Face-With-Sweat--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':astonished_face:', assetPath: 'assets/chat_emojis/Astonished-Face--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':face_with_open_mouth:', assetPath: 'assets/chat_emojis/Face-With-Open-Mouth--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':face_screaming_in_fear:', assetPath: 'assets/chat_emojis/Face-Screaming-In-Fear--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':face_with_hand_over_mouth:', assetPath: 'assets/chat_emojis/Face-With-Hand-Over-Mouth--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':face_with_monocle:', assetPath: 'assets/chat_emojis/Face-With-Monocle--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':face_vomiting:', assetPath: 'assets/chat_emojis/Face-Vomiting--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':confounded_face:', assetPath: 'assets/chat_emojis/Confounded-Face--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':angry_face:', assetPath: 'assets/chat_emojis/Angry-Face--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':angry_face_with_horns:', assetPath: 'assets/chat_emojis/Angry-Face-With-Horns--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':star_struck:', assetPath: 'assets/chat_emojis/Star-Struck--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':smiling_face_with_heart_eyes:', assetPath: 'assets/chat_emojis/Smiling-Face-With-Heart-Eyes--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':smiling_face_with_hearts:', assetPath: 'assets/chat_emojis/Smiling-Face-With-Hearts--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':face_with_tears_of_joy:', assetPath: 'assets/chat_emojis/Face-With-Tears-Of-Joy--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':rolling_on_the_floor_laughing:', assetPath: 'assets/chat_emojis/Rolling-On-The-Floor-Laughing--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':pleading_face:', assetPath: 'assets/chat_emojis/Pleading-Face--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':crying_face:', assetPath: 'assets/chat_emojis/Crying-Face--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':loudly_crying_face:', assetPath: 'assets/chat_emojis/Loudly-Crying-Face--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':hot_face:', assetPath: 'assets/chat_emojis/Hot-Face--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':cold_face:', assetPath: 'assets/chat_emojis/Cold-Face--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':zany_face:', assetPath: 'assets/chat_emojis/Zany-Face--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':upside_down_face:', assetPath: 'assets/chat_emojis/Upside-Down-Face--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':sleepy_face:', assetPath: 'assets/chat_emojis/Sleepy-Face--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':yawning_face:', assetPath: 'assets/chat_emojis/Yawning-Face--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':exploding_head:', assetPath: 'assets/chat_emojis/Exploding-Head--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':face_with_symbol_on_mouth:', assetPath: 'assets/chat_emojis/Face-With-Symbol-On-Mouth--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':ghost:', assetPath: 'assets/chat_emojis/Ghost--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':skull:', assetPath: 'assets/chat_emojis/Skull--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':skull_and_crossbones:', assetPath: 'assets/chat_emojis/Skull-And-Crossbones--Streamline-Kawaii-Emoji.png', categoryKey: 'smileys'),
    ChatEmoji(token: ':thumbs_up:', assetPath: 'assets/chat_emojis/Thumbs-Up--Streamline-Kawaii-Emoji.png', categoryKey: 'people'),
    ChatEmoji(token: ':thumbs_down:', assetPath: 'assets/chat_emojis/Thumbs-Down--Streamline-Kawaii-Emoji.png', categoryKey: 'people'),
    ChatEmoji(token: ':ok_hand:', assetPath: 'assets/chat_emojis/Ok-Hand--Streamline-Kawaii-Emoji.png', categoryKey: 'people'),
    ChatEmoji(token: ':clapping_hands:', assetPath: 'assets/chat_emojis/Clapping-Hands--Streamline-Kawaii-Emoji.png', categoryKey: 'people'),
    ChatEmoji(token: ':folded_hands:', assetPath: 'assets/chat_emojis/Folded-Hands--Streamline-Kawaii-Emoji.png', categoryKey: 'people'),
    ChatEmoji(token: ':raised_hand:', assetPath: 'assets/chat_emojis/Raised-Hand--Streamline-Kawaii-Emoji.png', categoryKey: 'people'),
    ChatEmoji(token: ':waving_hand:', assetPath: 'assets/chat_emojis/Waving-Hand--Streamline-Kawaii-Emoji.png', categoryKey: 'people'),
    ChatEmoji(token: ':victory_hand:', assetPath: 'assets/chat_emojis/Victory-Hand--Streamline-Kawaii-Emoji.png', categoryKey: 'people'),
    ChatEmoji(token: ':love_you_gesture:', assetPath: 'assets/chat_emojis/Love-You-Gesture--Streamline-Kawaii-Emoji.png', categoryKey: 'people'),
    ChatEmoji(token: ':crossed_fingers:', assetPath: 'assets/chat_emojis/Crossed-Fingers--Streamline-Kawaii-Emoji.png', categoryKey: 'people'),
    ChatEmoji(token: ':handshake:', assetPath: 'assets/chat_emojis/Handshake--Streamline-Kawaii-Emoji.png', categoryKey: 'people'),
    ChatEmoji(token: ':open_hands:', assetPath: 'assets/chat_emojis/Open-Hands--Streamline-Kawaii-Emoji.png', categoryKey: 'people'),
    ChatEmoji(token: ':raising_hands:', assetPath: 'assets/chat_emojis/Raising-Hands--Streamline-Kawaii-Emoji.png', categoryKey: 'people'),
    ChatEmoji(token: ':middle_finger:', assetPath: 'assets/chat_emojis/Middle-Finger--Streamline-Kawaii-Emoji.png', categoryKey: 'people'),
    ChatEmoji(token: ':person:', assetPath: 'assets/chat_emojis/Person--Streamline-Kawaii-Emoji.png', categoryKey: 'people'),
    ChatEmoji(token: ':baby:', assetPath: 'assets/chat_emojis/Baby--Streamline-Kawaii-Emoji.png', categoryKey: 'people'),
    ChatEmoji(token: ':old_person:', assetPath: 'assets/chat_emojis/Old-Person--Streamline-Kawaii-Emoji.png', categoryKey: 'people'),
    ChatEmoji(token: ':selfie:', assetPath: 'assets/chat_emojis/Selfie--Streamline-Kawaii-Emoji.png', categoryKey: 'people'),
    ChatEmoji(token: ':writing_hand:', assetPath: 'assets/chat_emojis/Writing-Hand--Streamline-Kawaii-Emoji.png', categoryKey: 'people'),
    ChatEmoji(token: ':woman_facepalming:', assetPath: 'assets/chat_emojis/Woman-Facepalming--Streamline-Kawaii-Emoji.png', categoryKey: 'people'),
    ChatEmoji(token: ':man_facepalming:', assetPath: 'assets/chat_emojis/Man-Facepalming--Streamline-Kawaii-Emoji.png', categoryKey: 'people'),
    ChatEmoji(token: ':woman_raising_hand:', assetPath: 'assets/chat_emojis/Woman-Raising-Hand--Streamline-Kawaii-Emoji.png', categoryKey: 'people'),
    ChatEmoji(token: ':man_raising_hand:', assetPath: 'assets/chat_emojis/Man-Raising-Hand--Streamline-Kawaii-Emoji.png', categoryKey: 'people'),
    ChatEmoji(token: ':woman_tipping_hand:', assetPath: 'assets/chat_emojis/Woman-Tipping-Hand--Streamline-Kawaii-Emoji.png', categoryKey: 'people'),
    ChatEmoji(token: ':woman_bowing:', assetPath: 'assets/chat_emojis/Woman-Bowing--Streamline-Kawaii-Emoji.png', categoryKey: 'people'),
    ChatEmoji(token: ':woman_with_headscarf:', assetPath: 'assets/chat_emojis/Woman-With-Headscarf--Streamline-Kawaii-Emoji.png', categoryKey: 'people'),
    ChatEmoji(token: ':prince:', assetPath: 'assets/chat_emojis/Prince--Streamline-Kawaii-Emoji.png', categoryKey: 'people'),
    ChatEmoji(token: ':woman_firefighter:', assetPath: 'assets/chat_emojis/Woman-Firefighter--Streamline-Kawaii-Emoji.png', categoryKey: 'people'),
    ChatEmoji(token: ':man_firefighter:', assetPath: 'assets/chat_emojis/Man-Firefighter--Streamline-Kawaii-Emoji.png', categoryKey: 'people'),
    ChatEmoji(token: ':person_fencing:', assetPath: 'assets/chat_emojis/Person-Fencing--Streamline-Kawaii-Emoji.png', categoryKey: 'people'),
    ChatEmoji(token: ':dog_face:', assetPath: 'assets/chat_emojis/Dog-Face--Streamline-Kawaii-Emoji.png', categoryKey: 'animals_nature'),
    ChatEmoji(token: ':cat_face:', assetPath: 'assets/chat_emojis/Cat-Face--Streamline-Kawaii-Emoji.png', categoryKey: 'animals_nature'),
    ChatEmoji(token: ':dog:', assetPath: 'assets/chat_emojis/Dog--Streamline-Kawaii-Emoji.png', categoryKey: 'animals_nature'),
    ChatEmoji(token: ':cat_a:', assetPath: 'assets/chat_emojis/Cat-A--Streamline-Kawaii-Emoji.png', categoryKey: 'animals_nature'),
    ChatEmoji(token: ':monkey_face:', assetPath: 'assets/chat_emojis/Monkey-Face--Streamline-Kawaii-Emoji.png', categoryKey: 'animals_nature'),
    ChatEmoji(token: ':hear_no_evil_monkey:', assetPath: 'assets/chat_emojis/Hear-No-Evil-Monkey--Streamline-Kawaii-Emoji.png', categoryKey: 'animals_nature'),
    ChatEmoji(token: ':see_no_evil_monkey:', assetPath: 'assets/chat_emojis/See-No-Evil-Monkey--Streamline-Kawaii-Emoji.png', categoryKey: 'animals_nature'),
    ChatEmoji(token: ':speak_no_evil_monkey:', assetPath: 'assets/chat_emojis/Speak-No-Evil-Monkey--Streamline-Kawaii-Emoji.png', categoryKey: 'animals_nature'),
    ChatEmoji(token: ':unicorn:', assetPath: 'assets/chat_emojis/Unicorn--Streamline-Kawaii-Emoji.png', categoryKey: 'animals_nature'),
    ChatEmoji(token: ':dolphin:', assetPath: 'assets/chat_emojis/Dolphin--Streamline-Kawaii-Emoji.png', categoryKey: 'animals_nature'),
    ChatEmoji(token: ':bird:', assetPath: 'assets/chat_emojis/Bird--Streamline-Kawaii-Emoji.png', categoryKey: 'animals_nature'),
    ChatEmoji(token: ':blowfish:', assetPath: 'assets/chat_emojis/Blowfish--Streamline-Kawaii-Emoji.png', categoryKey: 'animals_nature'),
    ChatEmoji(token: ':badger:', assetPath: 'assets/chat_emojis/Badger--Streamline-Kawaii-Emoji.png', categoryKey: 'animals_nature'),
    ChatEmoji(token: ':bat:', assetPath: 'assets/chat_emojis/Bat--Streamline-Kawaii-Emoji.png', categoryKey: 'animals_nature'),
    ChatEmoji(token: ':t_rex:', assetPath: 'assets/chat_emojis/T-Rex--Streamline-Kawaii-Emoji.png', categoryKey: 'animals_nature'),
    ChatEmoji(token: ':lion:', assetPath: 'assets/chat_emojis/Lion--Streamline-Kawaii-Emoji.png', categoryKey: 'animals_nature'),
    ChatEmoji(token: ':tiger_face:', assetPath: 'assets/chat_emojis/Tiger-Face--Streamline-Kawaii-Emoji.png', categoryKey: 'animals_nature'),
    ChatEmoji(token: ':rabbit_face:', assetPath: 'assets/chat_emojis/Rabbit-Face--Streamline-Kawaii-Emoji.png', categoryKey: 'animals_nature'),
    ChatEmoji(token: ':mouse_face:', assetPath: 'assets/chat_emojis/Mouse-Face--Streamline-Kawaii-Emoji.png', categoryKey: 'animals_nature'),
    ChatEmoji(token: ':cow_face:', assetPath: 'assets/chat_emojis/Cow-Face--Streamline-Kawaii-Emoji.png', categoryKey: 'animals_nature'),
    ChatEmoji(token: ':pig_face:', assetPath: 'assets/chat_emojis/Pig-Face--Streamline-Kawaii-Emoji.png', categoryKey: 'animals_nature'),
    ChatEmoji(token: ':hamster:', assetPath: 'assets/chat_emojis/Hamster--Streamline-Kawaii-Emoji.png', categoryKey: 'animals_nature'),
    ChatEmoji(token: ':peacock:', assetPath: 'assets/chat_emojis/Peacock--Streamline-Kawaii-Emoji.png', categoryKey: 'animals_nature'),
    ChatEmoji(token: ':hedgehog:', assetPath: 'assets/chat_emojis/Hedgehog--Streamline-Kawaii-Emoji.png', categoryKey: 'animals_nature'),
    ChatEmoji(token: ':fox:', assetPath: 'assets/chat_emojis/Fox--Streamline-Kawaii-Emoji.png', categoryKey: 'animals_nature'),
    ChatEmoji(token: ':rose_a:', assetPath: 'assets/chat_emojis/Rose-A--Streamline-Kawaii-Emoji.png', categoryKey: 'animals_nature'),
    ChatEmoji(token: ':sunflower:', assetPath: 'assets/chat_emojis/Sunflower--Streamline-Kawaii-Emoji.png', categoryKey: 'animals_nature'),
    ChatEmoji(token: ':cactus:', assetPath: 'assets/chat_emojis/Cactus--Streamline-Kawaii-Emoji.png', categoryKey: 'animals_nature'),
    ChatEmoji(token: ':cloud:', assetPath: 'assets/chat_emojis/Cloud--Streamline-Kawaii-Emoji.png', categoryKey: 'animals_nature'),
    ChatEmoji(token: ':sun_with_face:', assetPath: 'assets/chat_emojis/Sun-With-Face--Streamline-Kawaii-Emoji.png', categoryKey: 'animals_nature'),
    ChatEmoji(token: ':sun:', assetPath: 'assets/chat_emojis/Sun--Streamline-Kawaii-Emoji.png', categoryKey: 'animals_nature'),
    ChatEmoji(token: ':crescent_moon:', assetPath: 'assets/chat_emojis/Crescent-Moon--Streamline-Kawaii-Emoji.png', categoryKey: 'animals_nature'),
    ChatEmoji(token: ':pizza:', assetPath: 'assets/chat_emojis/Pizza--Streamline-Kawaii-Emoji.png', categoryKey: 'food_drink'),
    ChatEmoji(token: ':hamburger:', assetPath: 'assets/chat_emojis/Hamburger--Streamline-Kawaii-Emoji.png', categoryKey: 'food_drink'),
    ChatEmoji(token: ':french_fries_a:', assetPath: 'assets/chat_emojis/French-Fries-A--Streamline-Kawaii-Emoji.png', categoryKey: 'food_drink'),
    ChatEmoji(token: ':hot_dog:', assetPath: 'assets/chat_emojis/Hot-Dog--Streamline-Kawaii-Emoji.png', categoryKey: 'food_drink'),
    ChatEmoji(token: ':birthday_cake:', assetPath: 'assets/chat_emojis/Birthday-Cake--Streamline-Kawaii-Emoji.png', categoryKey: 'food_drink'),
    ChatEmoji(token: ':doughnut_a:', assetPath: 'assets/chat_emojis/Doughnut-A--Streamline-Kawaii-Emoji.png', categoryKey: 'food_drink'),
    ChatEmoji(token: ':croissant:', assetPath: 'assets/chat_emojis/Croissant--Streamline-Kawaii-Emoji.png', categoryKey: 'food_drink'),
    ChatEmoji(token: ':burrito:', assetPath: 'assets/chat_emojis/Burrito--Streamline-Kawaii-Emoji.png', categoryKey: 'food_drink'),
    ChatEmoji(token: ':sushi:', assetPath: 'assets/chat_emojis/Sushi--Streamline-Kawaii-Emoji.png', categoryKey: 'food_drink'),
    ChatEmoji(token: ':spaghetti:', assetPath: 'assets/chat_emojis/Spaghetti--Streamline-Kawaii-Emoji.png', categoryKey: 'food_drink'),
    ChatEmoji(token: ':chocolate_bar:', assetPath: 'assets/chat_emojis/Chocolate-Bar--Streamline-Kawaii-Emoji.png', categoryKey: 'food_drink'),
    ChatEmoji(token: ':red_apple:', assetPath: 'assets/chat_emojis/Red-Apple--Streamline-Kawaii-Emoji.png', categoryKey: 'food_drink'),
    ChatEmoji(token: ':pineapple:', assetPath: 'assets/chat_emojis/Pineapple--Streamline-Kawaii-Emoji.png', categoryKey: 'food_drink'),
    ChatEmoji(token: ':kiwi_fruit:', assetPath: 'assets/chat_emojis/Kiwi-Fruit--Streamline-Kawaii-Emoji.png', categoryKey: 'food_drink'),
    ChatEmoji(token: ':coconut:', assetPath: 'assets/chat_emojis/Coconut--Streamline-Kawaii-Emoji.png', categoryKey: 'food_drink'),
    ChatEmoji(token: ':ear_of_corn:', assetPath: 'assets/chat_emojis/Ear-Of-Corn--Streamline-Kawaii-Emoji.png', categoryKey: 'food_drink'),
    ChatEmoji(token: ':bacon:', assetPath: 'assets/chat_emojis/Bacon--Streamline-Kawaii-Emoji.png', categoryKey: 'food_drink'),
    ChatEmoji(token: ':egg:', assetPath: 'assets/chat_emojis/Egg--Streamline-Kawaii-Emoji.png', categoryKey: 'food_drink'),
    ChatEmoji(token: ':tropical_drink:', assetPath: 'assets/chat_emojis/Tropical-Drink--Streamline-Kawaii-Emoji.png', categoryKey: 'food_drink'),
    ChatEmoji(token: ':clinking_glasses:', assetPath: 'assets/chat_emojis/Clinking-Glasses--Streamline-Kawaii-Emoji.png', categoryKey: 'food_drink'),
    ChatEmoji(token: ':teacup_without_handle:', assetPath: 'assets/chat_emojis/Teacup-Without-Handle--Streamline-Kawaii-Emoji.png', categoryKey: 'food_drink'),
    ChatEmoji(token: ':sake_b:', assetPath: 'assets/chat_emojis/Sake-B--Streamline-Kawaii-Emoji.png', categoryKey: 'food_drink'),
    ChatEmoji(token: ':bikini:', assetPath: 'assets/chat_emojis/Bikini--Streamline-Kawaii-Emoji.png', categoryKey: 'food_drink'),
    ChatEmoji(token: ':automobile:', assetPath: 'assets/chat_emojis/Automobile--Streamline-Kawaii-Emoji.png', categoryKey: 'travel_places'),
    ChatEmoji(token: ':oncoming_automobile:', assetPath: 'assets/chat_emojis/Oncoming-Automobile--Streamline-Kawaii-Emoji.png', categoryKey: 'travel_places'),
    ChatEmoji(token: ':bicycle:', assetPath: 'assets/chat_emojis/Bicycle--Streamline-Kawaii-Emoji.png', categoryKey: 'travel_places'),
    ChatEmoji(token: ':kick_scooter_a:', assetPath: 'assets/chat_emojis/Kick-Scooter-A--Streamline-Kawaii-Emoji.png', categoryKey: 'travel_places'),
    ChatEmoji(token: ':motor_scooter_b:', assetPath: 'assets/chat_emojis/Motor-Scooter-B--Streamline-Kawaii-Emoji.png', categoryKey: 'travel_places'),
    ChatEmoji(token: ':airplane_a:', assetPath: 'assets/chat_emojis/Airplane-A--Streamline-Kawaii-Emoji.png', categoryKey: 'travel_places'),
    ChatEmoji(token: ':airplane_b:', assetPath: 'assets/chat_emojis/Airplane-B--Streamline-Kawaii-Emoji.png', categoryKey: 'travel_places'),
    ChatEmoji(token: ':small_airplane:', assetPath: 'assets/chat_emojis/Small-Airplane--Streamline-Kawaii-Emoji.png', categoryKey: 'travel_places'),
    ChatEmoji(token: ':helicopter_b:', assetPath: 'assets/chat_emojis/Helicopter-B--Streamline-Kawaii-Emoji.png', categoryKey: 'travel_places'),
    ChatEmoji(token: ':rocket_b:', assetPath: 'assets/chat_emojis/Rocket-B--Streamline-Kawaii-Emoji.png', categoryKey: 'travel_places'),
    ChatEmoji(token: ':police_car_a:', assetPath: 'assets/chat_emojis/Police-Car-A--Streamline-Kawaii-Emoji.png', categoryKey: 'travel_places'),
    ChatEmoji(token: ':police_car_light_a:', assetPath: 'assets/chat_emojis/Police-Car-Light-A--Streamline-Kawaii-Emoji.png', categoryKey: 'travel_places'),
    ChatEmoji(token: ':light_rail:', assetPath: 'assets/chat_emojis/Light-Rail--Streamline-Kawaii-Emoji.png', categoryKey: 'travel_places'),
    ChatEmoji(token: ':roller_coaster_b:', assetPath: 'assets/chat_emojis/Roller-Coaster-B--Streamline-Kawaii-Emoji.png', categoryKey: 'travel_places'),
    ChatEmoji(token: ':church_a:', assetPath: 'assets/chat_emojis/Church-A--Streamline-Kawaii-Emoji.png', categoryKey: 'travel_places'),
    ChatEmoji(token: ':mosque_e:', assetPath: 'assets/chat_emojis/Mosque-E--Streamline-Kawaii-Emoji.png', categoryKey: 'travel_places'),
    ChatEmoji(token: ':house_b:', assetPath: 'assets/chat_emojis/House-B--Streamline-Kawaii-Emoji.png', categoryKey: 'travel_places'),
    ChatEmoji(token: ':office_building_b:', assetPath: 'assets/chat_emojis/Office-Building-B--Streamline-Kawaii-Emoji.png', categoryKey: 'travel_places'),
    ChatEmoji(token: ':sunrise_over_mountains_a:', assetPath: 'assets/chat_emojis/Sunrise-Over-Mountains-A--Streamline-Kawaii-Emoji.png', categoryKey: 'travel_places'),
    ChatEmoji(token: ':night_with_stars_a:', assetPath: 'assets/chat_emojis/Night-With-Stars-A--Streamline-Kawaii-Emoji.png', categoryKey: 'travel_places'),
    ChatEmoji(token: ':bell:', assetPath: 'assets/chat_emojis/Bell--Streamline-Kawaii-Emoji.png', categoryKey: 'objects'),
    ChatEmoji(token: ':bell_with_slash_a:', assetPath: 'assets/chat_emojis/Bell-With-Slash-A--Streamline-Kawaii-Emoji.png', categoryKey: 'objects'),
    ChatEmoji(token: ':balloon:', assetPath: 'assets/chat_emojis/Balloon--Streamline-Kawaii-Emoji.png', categoryKey: 'objects'),
    ChatEmoji(token: ':wrapped_gift_a:', assetPath: 'assets/chat_emojis/Wrapped-Gift-A--Streamline-Kawaii-Emoji.png', categoryKey: 'objects'),
    ChatEmoji(token: ':ribbon:', assetPath: 'assets/chat_emojis/Ribbon--Streamline-Kawaii-Emoji.png', categoryKey: 'objects'),
    ChatEmoji(token: ':desktop_computer:', assetPath: 'assets/chat_emojis/Desktop-Computer--Streamline-Kawaii-Emoji.png', categoryKey: 'objects'),
    ChatEmoji(token: ':television_b:', assetPath: 'assets/chat_emojis/Television-B--Streamline-Kawaii-Emoji.png', categoryKey: 'objects'),
    ChatEmoji(token: ':control_knobs:', assetPath: 'assets/chat_emojis/Control-Knobs--Streamline-Kawaii-Emoji.png', categoryKey: 'objects'),
    ChatEmoji(token: ':floppy_disk:', assetPath: 'assets/chat_emojis/Floppy-Disk--Streamline-Kawaii-Emoji.png', categoryKey: 'objects'),
    ChatEmoji(token: ':battery_a:', assetPath: 'assets/chat_emojis/Battery-A--Streamline-Kawaii-Emoji.png', categoryKey: 'objects'),
    ChatEmoji(token: ':e_mail_a:', assetPath: 'assets/chat_emojis/E-Mail-A--Streamline-Kawaii-Emoji.png', categoryKey: 'objects'),
    ChatEmoji(token: ':envelope:', assetPath: 'assets/chat_emojis/Envelope--Streamline-Kawaii-Emoji.png', categoryKey: 'objects'),
    ChatEmoji(token: ':fax_machine_b:', assetPath: 'assets/chat_emojis/Fax-Machine-B--Streamline-Kawaii-Emoji.png', categoryKey: 'objects'),
    ChatEmoji(token: ':film_frames:', assetPath: 'assets/chat_emojis/Film-Frames--Streamline-Kawaii-Emoji.png', categoryKey: 'objects'),
    ChatEmoji(token: ':card_index:', assetPath: 'assets/chat_emojis/Card-Index--Streamline-Kawaii-Emoji.png', categoryKey: 'objects'),
    ChatEmoji(token: ':abacus:', assetPath: 'assets/chat_emojis/Abacus--Streamline-Kawaii-Emoji.png', categoryKey: 'objects'),
    ChatEmoji(token: ':fire_extinguisher:', assetPath: 'assets/chat_emojis/Fire-Extinguisher--Streamline-Kawaii-Emoji.png', categoryKey: 'objects'),
    ChatEmoji(token: ':teddy_bear:', assetPath: 'assets/chat_emojis/Teddy-Bear--Streamline-Kawaii-Emoji.png', categoryKey: 'objects'),
    ChatEmoji(token: ':saxophone:', assetPath: 'assets/chat_emojis/Saxophone--Streamline-Kawaii-Emoji.png', categoryKey: 'objects'),
    ChatEmoji(token: ':drum:', assetPath: 'assets/chat_emojis/Drum--Streamline-Kawaii-Emoji.png', categoryKey: 'objects'),
    ChatEmoji(token: ':guitar:', assetPath: 'assets/chat_emojis/Guitar--Streamline-Kawaii-Emoji.png', categoryKey: 'objects'),
    ChatEmoji(token: ':gemini_a:', assetPath: 'assets/chat_emojis/Gemini-A--Streamline-Kawaii-Emoji.png', categoryKey: 'objects'),
    ChatEmoji(token: ':red_heart:', assetPath: 'assets/chat_emojis/Red-Heart--Streamline-Kawaii-Emoji.png', categoryKey: 'symbols'),
    ChatEmoji(token: ':orange_heart:', assetPath: 'assets/chat_emojis/Orange-Heart--Streamline-Kawaii-Emoji.png', categoryKey: 'symbols'),
    ChatEmoji(token: ':green_heart:', assetPath: 'assets/chat_emojis/Green-Heart--Streamline-Kawaii-Emoji.png', categoryKey: 'symbols'),
    ChatEmoji(token: ':blue_heart:', assetPath: 'assets/chat_emojis/Blue-Heart--Streamline-Kawaii-Emoji.png', categoryKey: 'symbols'),
    ChatEmoji(token: ':purple_heart:', assetPath: 'assets/chat_emojis/Purple-Heart--Streamline-Kawaii-Emoji.png', categoryKey: 'symbols'),
    ChatEmoji(token: ':black_heart:', assetPath: 'assets/chat_emojis/Black-Heart--Streamline-Kawaii-Emoji.png', categoryKey: 'symbols'),
    ChatEmoji(token: ':brown_heart:', assetPath: 'assets/chat_emojis/Brown-Heart--Streamline-Kawaii-Emoji.png', categoryKey: 'symbols'),
    ChatEmoji(token: ':broken_heart:', assetPath: 'assets/chat_emojis/Broken-Heart--Streamline-Kawaii-Emoji.png', categoryKey: 'symbols'),
    ChatEmoji(token: ':growing_heart:', assetPath: 'assets/chat_emojis/Growing-Heart--Streamline-Kawaii-Emoji.png', categoryKey: 'symbols'),
    ChatEmoji(token: ':beating_heart:', assetPath: 'assets/chat_emojis/Beating-Heart--Streamline-Kawaii-Emoji.png', categoryKey: 'symbols'),
    ChatEmoji(token: ':heart_with_arrow:', assetPath: 'assets/chat_emojis/Heart-With-Arrow--Streamline-Kawaii-Emoji.png', categoryKey: 'symbols'),
    ChatEmoji(token: ':heart_with_ribbon:', assetPath: 'assets/chat_emojis/Heart-With-Ribbon--Streamline-Kawaii-Emoji.png', categoryKey: 'symbols'),
    ChatEmoji(token: ':heart_exclamation:', assetPath: 'assets/chat_emojis/Heart-Exclamation--Streamline-Kawaii-Emoji.png', categoryKey: 'symbols'),
    ChatEmoji(token: ':heart_decoration:', assetPath: 'assets/chat_emojis/Heart-Decoration--Streamline-Kawaii-Emoji.png', categoryKey: 'symbols'),
    ChatEmoji(token: ':check_mark:', assetPath: 'assets/chat_emojis/Check-Mark--Streamline-Kawaii-Emoji.png', categoryKey: 'symbols'),
    ChatEmoji(token: ':check_mark_button:', assetPath: 'assets/chat_emojis/Check-Mark-Button--Streamline-Kawaii-Emoji.png', categoryKey: 'symbols'),
    ChatEmoji(token: ':cross_mark:', assetPath: 'assets/chat_emojis/Cross-Mark--Streamline-Kawaii-Emoji.png', categoryKey: 'symbols'),
    ChatEmoji(token: ':cross_mark_button:', assetPath: 'assets/chat_emojis/Cross-Mark-Button--Streamline-Kawaii-Emoji.png', categoryKey: 'symbols'),
    ChatEmoji(token: ':double_exclamation_mark:', assetPath: 'assets/chat_emojis/Double-Exclamation-Mark--Streamline-Kawaii-Emoji.png', categoryKey: 'symbols'),
    ChatEmoji(token: ':fire:', assetPath: 'assets/chat_emojis/Fire--Streamline-Kawaii-Emoji.png', categoryKey: 'symbols'),
    ChatEmoji(token: ':glowing_star:', assetPath: 'assets/chat_emojis/Glowing-Star--Streamline-Kawaii-Emoji.png', categoryKey: 'symbols'),
    ChatEmoji(token: ':star_a:', assetPath: 'assets/chat_emojis/Star-A--Streamline-Kawaii-Emoji.png', categoryKey: 'symbols'),
    ChatEmoji(token: ':shooting_star_a:', assetPath: 'assets/chat_emojis/Shooting-Star-A--Streamline-Kawaii-Emoji.png', categoryKey: 'symbols'),
    ChatEmoji(token: ':blue_circle:', assetPath: 'assets/chat_emojis/Blue-Circle--Streamline-Kawaii-Emoji.png', categoryKey: 'symbols'),
    ChatEmoji(token: ':white_flower:', assetPath: 'assets/chat_emojis/White-Flower--Streamline-Kawaii-Emoji.png', categoryKey: 'symbols'),
    ChatEmoji(token: ':biohazard:', assetPath: 'assets/chat_emojis/Biohazard--Streamline-Kawaii-Emoji.png', categoryKey: 'symbols'),
  ];

  static ChatEmoji? byToken(String token) {
    final normalizedToken = legacyAliases[token] ?? token;
    for (final emoji in emojis) {
      if (emoji.token == normalizedToken) return emoji;
    }
    return null;
  }

  static List<ChatEmoji> forCategory(String categoryKey) {
    return emojis.where((emoji) => emoji.categoryKey == categoryKey).toList(growable: false);
  }

  static String notificationPreviewText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return text;
    final matches = tokenPattern.allMatches(trimmed).toList();
    final compact = matches.map((match) => match.group(0)!).join(' ');
    if (matches.isNotEmpty && compact.length == trimmed.length) {
      final count = matches.length;
      return count == 1 ? 'Sent an emoji' : 'Sent $count emojis';
    }
    return trimmed.replaceAllMapped(tokenPattern, (match) {
      final emoji = byToken(match.group(0)!);
      return emoji != null ? '[emoji]' : match.group(0)!;
    });
  }

  static Widget buildInlinePreview(
    String text, {
    required double fontSize,
    required Color textColor,
    double emojiSize = 18,
    int? maxLines,
    TextOverflow overflow = TextOverflow.clip,
  }) {
    final matches = tokenPattern.allMatches(text).toList();
    if (matches.isEmpty) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: overflow,
        style: GoogleFonts.outfit(color: textColor, fontSize: fontSize, height: 1.35),
      );
    }
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in matches) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start), style: GoogleFonts.outfit(color: textColor, fontSize: fontSize, height: 1.35)));
      }
      final token = match.group(0)!;
      final emoji = byToken(token);
      if (emoji != null) {
        spans.add(WidgetSpan(alignment: PlaceholderAlignment.middle, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 1), child: Image.asset(emoji.assetPath, width: emojiSize, height: emojiSize, fit: BoxFit.contain))));
      } else {
        spans.add(TextSpan(text: token, style: GoogleFonts.outfit(color: textColor, fontSize: fontSize, height: 1.35)));
      }
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: GoogleFonts.outfit(color: textColor, fontSize: fontSize, height: 1.35)));
    }
    return RichText(maxLines: maxLines, overflow: overflow, text: TextSpan(style: GoogleFonts.outfit(color: textColor, fontSize: fontSize, height: 1.35), children: spans));
  }

  static String? singleEmojiAssetPath(String text) {
    final trimmed = text.trim();
    final match = tokenPattern.matchAsPrefix(trimmed);
    if (match == null || match.end != trimmed.length) return null;
    return byToken(trimmed)?.assetPath;
  }

  static List<ChatEmoji> extractEmojis(String text) {
    return tokenPattern
        .allMatches(text)
        .map((match) => byToken(match.group(0)!))
        .whereType<ChatEmoji>()
        .toList(growable: false);
  }

  static String stripEmojiTokens(String text) {
    return text.replaceAllMapped(tokenPattern, (_) => '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
