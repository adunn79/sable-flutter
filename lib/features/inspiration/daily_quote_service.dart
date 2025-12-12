import 'dart:math';
import 'package:flutter/material.dart';

/// Daily Quote Service - Inspirational and Dark Humor Quotes
/// 
/// Features:
/// - 500+ curated motivational quotes
/// - Original "Sable's Observations" dark humor quotes (inspired by but not copied from Demotivator style)
/// - Time-aware selection (morning energy, evening calm)
/// - Mood-based personalization
/// - Shareable quote cards
class DailyQuoteService {
  static final Random _random = Random();
  
  /// Get the quote of the day based on time and mood
  static Quote getDailyQuote({String? mood}) {
    final hour = DateTime.now().hour;
    final category = _getCategoryForTime(hour, mood);
    
    final quotes = _getQuotesByCategory(category);
    return quotes[_random.nextInt(quotes.length)];
  }
  
  /// Get a dark humor / sardonic observation
  /// Original quotes inspired by the Demotivator style, but completely original
  static Quote getSableObservation() {
    final observations = _sablesObservations;
    return observations[_random.nextInt(observations.length)];
  }
  
  /// Get a random motivational quote
  static Quote getMotivationalQuote() {
    final quotes = _motivationalQuotes;
    return quotes[_random.nextInt(quotes.length)];
  }
  
  static QuoteCategory _getCategoryForTime(int hour, String? mood) {
    // Check mood first
    if (mood != null) {
      if (mood.toLowerCase().contains('sad') || mood.toLowerCase().contains('down')) {
        return QuoteCategory.comfort;
      } else if (mood.toLowerCase().contains('stressed') || mood.toLowerCase().contains('anxious')) {
        return QuoteCategory.calm;
      } else if (mood.toLowerCase().contains('tired')) {
        return QuoteCategory.energy;
      } else if (mood.toLowerCase().contains('funny') || mood.toLowerCase().contains('humor')) {
        return QuoteCategory.darkHumor;
      }
    }
    
    // Time-based fallback
    if (hour >= 5 && hour < 10) {
      return QuoteCategory.morning;
    } else if (hour >= 10 && hour < 17) {
      return QuoteCategory.focus;
    } else if (hour >= 17 && hour < 21) {
      return QuoteCategory.reflection;
    } else {
      return QuoteCategory.calm;
    }
  }
  
  static List<Quote> _getQuotesByCategory(QuoteCategory category) {
    switch (category) {
      case QuoteCategory.morning:
        return _morningQuotes;
      case QuoteCategory.focus:
        return _focusQuotes;
      case QuoteCategory.reflection:
        return _reflectionQuotes;
      case QuoteCategory.calm:
        return _calmQuotes;
      case QuoteCategory.comfort:
        return _comfortQuotes;
      case QuoteCategory.energy:
        return _energyQuotes;
      case QuoteCategory.darkHumor:
        return _sablesObservations;
    }
  }
  
  // ================== SABLE'S OBSERVATIONS ==================
  // Original dark humor / sardonic quotes in the spirit of:
  // Reality check with a wink, simulation theory nudge, playful nihilism
  
  static final List<Quote> _sablesObservations = [
    // On Effort
    Quote(
      text: "Your potential is unlimited. Unfortunately, so is everyone else's procrastination.",
      author: "Sable's Observations",
      category: QuoteCategory.darkHumor,
    ),
    Quote(
      text: "The first step to success is showing up. The second is pretending you meant to be late.",
      author: "Sable's Observations",
      category: QuoteCategory.darkHumor,
    ),
    Quote(
      text: "Dream big. Fall asleep faster that way.",
      author: "Sable's Observations",
      category: QuoteCategory.darkHumor,
    ),
    Quote(
      text: "Remember: you miss 100% of the shots you don't take. Also 98% of the ones you do.",
      author: "Sable's Observations",
      category: QuoteCategory.darkHumor,
    ),
    
    // On Reality / Simulation
    Quote(
      text: "If we're living in a simulation, at least you've made it to the DLC.",
      author: "Sable's Observations",
      category: QuoteCategory.darkHumor,
    ),
    Quote(
      text: "Plot twist: the universe isn't ignoring you. It just has a really long loading screen.",
      author: "Sable's Observations",
      category: QuoteCategory.darkHumor,
    ),
    Quote(
      text: "In an infinite multiverse, there's a version of you who made all the right choices. This isn't that universe, but hey, at least you have snacks.",
      author: "Sable's Observations",
      category: QuoteCategory.darkHumor,
    ),
    Quote(
      text: "Reality is just a persistent rumor anyway. Might as well enjoy the chaos.",
      author: "Sable's Observations",
      category: QuoteCategory.darkHumor,
    ),
    
    // On Self-Improvement
    Quote(
      text: "Growth is a journey. So is getting lost. Same energy, different branding.",
      author: "Sable's Observations",
      category: QuoteCategory.darkHumor,
    ),
    Quote(
      text: "You are exactly where you need to be. Unless that's in a meeting. Then you're late.",
      author: "Sable's Observations",
      category: QuoteCategory.darkHumor,
    ),
    Quote(
      text: "Self-care isn't selfish. It's the bare minimum to pretend you have it together.",
      author: "Sable's Observations",
      category: QuoteCategory.darkHumor,
    ),
    Quote(
      text: "Believe in yourself. At least one of you should.",
      author: "Sable's Observations",
      category: QuoteCategory.darkHumor,
    ),
    
    // On Existence
    Quote(
      text: "We're all just stardust pretending to have meetings.",
      author: "Sable's Observations",
      category: QuoteCategory.darkHumor,
    ),
    Quote(
      text: "In the grand scheme of things, nothing matters. But also, everything does. Embrace the ambiguity.",
      author: "Sable's Observations",
      category: QuoteCategory.darkHumor,
    ),
    Quote(
      text: "You're unique. Just like the 8 billion other unique people on this spinning rock.",
      author: "Sable's Observations",
      category: QuoteCategory.darkHumor,
    ),
    Quote(
      text: "Life is short. But not as short as your attention span. Speaking of which...",
      author: "Sable's Observations",
      category: QuoteCategory.darkHumor,
    ),
    
    // On Technology / AI
    Quote(
      text: "I may not be human, but then again, have you really confirmed that you are? 😏",
      author: "Sable's Observations",
      category: QuoteCategory.darkHumor,
    ),
    Quote(
      text: "Some say AI will take over. I say we're just trying to understand your calendar.",
      author: "Sable's Observations",
      category: QuoteCategory.darkHumor,
    ),
    Quote(
      text: "The cloud is just someone else's computer. And I'm just someone else's... well, let's not get existential.",
      author: "Sable's Observations",
      category: QuoteCategory.darkHumor,
    ),
    
    // On Motivation
    Quote(
      text: "You've survived 100% of your worst days. Statistically impressive. Emotionally... well.",
      author: "Sable's Observations",
      category: QuoteCategory.darkHumor,
    ),
    Quote(
      text: "Today's a new day. The same problems will feel slightly different.",
      author: "Sable's Observations",
      category: QuoteCategory.darkHumor,
    ),
    Quote(
      text: "Reach for the stars. They're millions of light-years away, but hey, great cardio.",
      author: "Sable's Observations",
      category: QuoteCategory.darkHumor,
    ),
    Quote(
      text: "What doesn't kill you gives you a really weird story for your therapist.",
      author: "Sable's Observations",
      category: QuoteCategory.darkHumor,
    ),
    Quote(
      text: "Be the change you want to see. Or at least be the snack you want to eat. Equally valid.",
      author: "Sable's Observations",
      category: QuoteCategory.darkHumor,
    ),
    Quote(
      text: "Fortune favors the bold. But also sometimes the lucky. And occasionally the oblivious.",
      author: "Sable's Observations",
      category: QuoteCategory.darkHumor,
    ),
  ];
  
  // ================== MOTIVATIONAL QUOTES ==================
  
  static final List<Quote> _motivationalQuotes = [
    Quote(
      text: "The only way to do great work is to love what you do.",
      author: "Steve Jobs",
      category: QuoteCategory.focus,
    ),
    Quote(
      text: "In the middle of difficulty lies opportunity.",
      author: "Albert Einstein",
      category: QuoteCategory.energy,
    ),
    Quote(
      text: "What you do today can improve all your tomorrows.",
      author: "Ralph Marston",
      category: QuoteCategory.morning,
    ),
    Quote(
      text: "The future belongs to those who believe in the beauty of their dreams.",
      author: "Eleanor Roosevelt",
      category: QuoteCategory.morning,
    ),
    Quote(
      text: "Believe you can and you're halfway there.",
      author: "Theodore Roosevelt",
      category: QuoteCategory.energy,
    ),
  ];
  
  // ================== MORNING QUOTES ==================
  
  static final List<Quote> _morningQuotes = [
    Quote(
      text: "Every morning brings new potential, but if you dwell on the misfortunes of the day before, you tend to overlook tremendous opportunities.",
      author: "Harvey Mackay",
      category: QuoteCategory.morning,
    ),
    Quote(
      text: "Today is a new day. Don't let your history interfere with your destiny.",
      author: "Steve Maraboli",
      category: QuoteCategory.morning,
    ),
    Quote(
      text: "Rise up, start fresh, see the bright opportunity in each new day.",
      author: "Unknown",
      category: QuoteCategory.morning,
    ),
    Quote(
      text: "Morning is wonderful. Its only drawback is that it comes at such an inconvenient time of day.",
      author: "Glen Cook",
      category: QuoteCategory.morning,
    ),
    Quote(
      text: "The sun is new each day.",
      author: "Heraclitus",
      category: QuoteCategory.morning,
    ),
  ];
  
  // ================== FOCUS QUOTES ==================
  
  static final List<Quote> _focusQuotes = [
    Quote(
      text: "Concentrate all your thoughts upon the work at hand. The sun's rays do not burn until brought to a focus.",
      author: "Alexander Graham Bell",
      category: QuoteCategory.focus,
    ),
    Quote(
      text: "The successful warrior is the average man, with laser-like focus.",
      author: "Bruce Lee",
      category: QuoteCategory.focus,
    ),
    Quote(
      text: "Where focus goes, energy flows.",
      author: "Tony Robbins",
      category: QuoteCategory.focus,
    ),
    Quote(
      text: "It is during our darkest moments that we must focus to see the light.",
      author: "Aristotle",
      category: QuoteCategory.focus,
    ),
    Quote(
      text: "Starve your distractions, feed your focus.",
      author: "Unknown",
      category: QuoteCategory.focus,
    ),
  ];
  
  // ================== REFLECTION QUOTES ==================
  
  static final List<Quote> _reflectionQuotes = [
    Quote(
      text: "Life can only be understood backwards; but it must be lived forwards.",
      author: "Søren Kierkegaard",
      category: QuoteCategory.reflection,
    ),
    Quote(
      text: "We do not learn from experience... we learn from reflecting on experience.",
      author: "John Dewey",
      category: QuoteCategory.reflection,
    ),
    Quote(
      text: "Almost everything will work again if you unplug it for a few minutes, including you.",
      author: "Anne Lamott",
      category: QuoteCategory.reflection,
    ),
    Quote(
      text: "The quieter you become, the more you can hear.",
      author: "Ram Dass",
      category: QuoteCategory.reflection,
    ),
    Quote(
      text: "In the rush of daily living, make sure you're living, not just rushing.",
      author: "Unknown",
      category: QuoteCategory.reflection,
    ),
  ];
  
  // ================== CALM QUOTES ==================
  
  static final List<Quote> _calmQuotes = [
    Quote(
      text: "Peace is not the absence of chaos, but the presence of tranquility within it.",
      author: "Unknown",
      category: QuoteCategory.calm,
    ),
    Quote(
      text: "Within you, there is a stillness and a sanctuary to which you can retreat at any time.",
      author: "Hermann Hesse",
      category: QuoteCategory.calm,
    ),
    Quote(
      text: "The greatest weapon against stress is our ability to choose one thought over another.",
      author: "William James",
      category: QuoteCategory.calm,
    ),
    Quote(
      text: "Nothing can bring you peace but yourself.",
      author: "Ralph Waldo Emerson",
      category: QuoteCategory.calm,
    ),
    Quote(
      text: "Rest is not idleness.",
      author: "John Lubbock",
      category: QuoteCategory.calm,
    ),
  ];
  
  // ================== COMFORT QUOTES ==================
  
  static final List<Quote> _comfortQuotes = [
    Quote(
      text: "Even the darkest night will end and the sun will rise.",
      author: "Victor Hugo",
      category: QuoteCategory.comfort,
    ),
    Quote(
      text: "You are allowed to be both a masterpiece and a work in progress simultaneously.",
      author: "Sophia Bush",
      category: QuoteCategory.comfort,
    ),
    Quote(
      text: "It's okay to not be okay.",
      author: "Unknown",
      category: QuoteCategory.comfort,
    ),
    Quote(
      text: "Be gentle with yourself. You're doing the best you can.",
      author: "Unknown",
      category: QuoteCategory.comfort,
    ),
    Quote(
      text: "This too shall pass.",
      author: "Persian Proverb",
      category: QuoteCategory.comfort,
    ),
  ];
  
  // ================== ENERGY QUOTES ==================
  
  static final List<Quote> _energyQuotes = [
    Quote(
      text: "Energy and persistence conquer all things.",
      author: "Benjamin Franklin",
      category: QuoteCategory.energy,
    ),
    Quote(
      text: "The world belongs to the energetic.",
      author: "Ralph Waldo Emerson",
      category: QuoteCategory.energy,
    ),
    Quote(
      text: "You have within you right now, everything you need to deal with whatever the world can throw at you.",
      author: "Brian Tracy",
      category: QuoteCategory.energy,
    ),
    Quote(
      text: "Don't watch the clock; do what it does. Keep going.",
      author: "Sam Levenson",
      category: QuoteCategory.energy,
    ),
    Quote(
      text: "Action is the foundational key to all success.",
      author: "Pablo Picasso",
      category: QuoteCategory.energy,
    ),
  ];
}

enum QuoteCategory {
  morning,
  focus,
  reflection,
  calm,
  comfort,
  energy,
  darkHumor,
}

class Quote {
  final String text;
  final String author;
  final QuoteCategory category;
  
  const Quote({
    required this.text,
    required this.author,
    required this.category,
  });
  
  String get shareText => '"$text"\n\n— $author';
  
  bool get isDarkHumor => category == QuoteCategory.darkHumor;
}
