import 'package:flutter/material.dart';

enum AppHelpTopic {
  home,
  schedule,
  recipes,
  shopping,
  profile,
  kitchen,
}

class HelpFaqItem {
  const HelpFaqItem({
    required this.question,
    required this.answer,
  });

  final String question;
  final String answer;
}

class AppHelpContent {
  const AppHelpContent({
    required this.topic,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.bullets,
    required this.faqs,
  });

  final AppHelpTopic topic;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> bullets;
  final List<HelpFaqItem> faqs;
}

AppHelpContent appHelpForTopic(AppHelpTopic topic) {
  switch (topic) {
    case AppHelpTopic.home:
      return const AppHelpContent(
        topic: AppHelpTopic.home,
        title: 'Home',
        subtitle: 'Your discovery feed for recipes from the community.',
        icon: Icons.explore_rounded,
        bullets: [
          'Use the tabs at the top to switch between For You, Trending, Friends, and Seasonal.',
          'Tap any recipe card to see the full recipe, like it, fork it, or share it.',
          'Use search to find specific people, recipes, ingredients, and cuisines faster.',
        ],
        faqs: [
          HelpFaqItem(
            question: 'Why does my Home feed look empty?',
            answer:
                'Your feed gets better once you follow people, save recipes, and set your preferences.',
          ),
          HelpFaqItem(
            question: 'What is the difference between Trending and Friends?',
            answer:
                'Trending shows popular recipes across the app, while Friends shows recipes from people you follow.',
          ),
        ],
      );
    case AppHelpTopic.schedule:
      return const AppHelpContent(
        topic: AppHelpTopic.schedule,
        title: 'Schedule',
        subtitle: 'Plan meals for your kitchen week by week.',
        icon: Icons.calendar_month_rounded,
        bullets: [
          'Tap an empty meal slot to add one of your recipes, a kitchen member recipe, or a freeform meal.',
          'If you are not a kitchen lead or editor, your additions are sent as suggestions for approval.',
          'Use the Kitchen tab when you need invite codes, members, permissions, or kitchen recipes.',
        ],
        faqs: [
          HelpFaqItem(
            question: 'Why was my meal not added right away?',
            answer:
                'If you do not have edit permission in the kitchen, your meal is saved as a suggestion until a lead or approver confirms it.',
          ),
          HelpFaqItem(
            question: 'Can I add meals that are not recipes?',
            answer:
                'Yes. Choose the Freeform option for meals like leftovers, takeout, or eating out.',
          ),
        ],
      );
    case AppHelpTopic.recipes:
      return const AppHelpContent(
        topic: AppHelpTopic.recipes,
        title: 'Recipe Book',
        subtitle: 'Your personal library for everything you cook and save.',
        icon: Icons.menu_book_rounded,
        bullets: [
          'All shows your own recipes, Liked shows saved recipes, and Remixed shows forks you made.',
          'Private recipes stay just for you; shared recipes can appear in your kitchen and social surfaces.',
          'Use the import button to bring in recipes from supported links.',
        ],
        faqs: [
          HelpFaqItem(
            question: 'What is a remixed recipe?',
            answer:
                'A remixed recipe is your own forked copy of someone else’s recipe, which you can edit independently.',
          ),
          HelpFaqItem(
            question: 'Why can’t someone else schedule one of my recipes?',
            answer:
                'Only shared recipes can be used by other people in the kitchen. Private recipes are hidden from everyone else.',
          ),
        ],
      );
    case AppHelpTopic.shopping:
      return const AppHelpContent(
        topic: AppHelpTopic.shopping,
        title: 'Shopping',
        subtitle: 'Create grocery lists manually or generate them from the schedule.',
        icon: Icons.shopping_bag_rounded,
        bullets: [
          'Create a list manually with the New List button whenever you want a simple grocery list.',
          'Use the calendar button to generate a shopping list from scheduled meals.',
          'Kitchen shopping lists are shared, so everyone in the kitchen can check off items together.',
        ],
        faqs: [
          HelpFaqItem(
            question: 'What does generate from schedule do?',
            answer:
                'It looks at scheduled recipe ingredients in the date range you choose and builds one combined list.',
          ),
          HelpFaqItem(
            question: 'Will my kitchen see my shopping list?',
            answer:
                'If you are in a kitchen, the shared kitchen list is visible to members. Personal lists stay personal.',
          ),
        ],
      );
    case AppHelpTopic.profile:
      return const AppHelpContent(
        topic: AppHelpTopic.profile,
        title: 'Profile',
        subtitle: 'Manage your account, your public presence, and your settings.',
        icon: Icons.person_rounded,
        bullets: [
          'Use Edit Profile to update your name, photo, bio, and preferences.',
          'Settings contains notifications, subscription, onboarding replay, and help.',
          'Your profile is now a quick top-bar destination so Kitchen can stay in the main bottom navigation.',
        ],
        faqs: [
          HelpFaqItem(
            question: 'Where do I change account preferences later?',
            answer:
                'Open Settings from your profile to manage notifications, account details, and support options.',
          ),
          HelpFaqItem(
            question: 'Can I make recipes private from my profile?',
            answer:
                'Recipe privacy is managed on the recipe itself, but your profile helps you keep track of public versus private counts.',
          ),
        ],
      );
    case AppHelpTopic.kitchen:
      return const AppHelpContent(
        topic: AppHelpTopic.kitchen,
        title: 'Kitchen',
        subtitle: 'Your shared space for planning meals with other members.',
        icon: Icons.kitchen_rounded,
        bullets: [
          'Kitchen is one of the main bottom tabs because it is a core part of planning together.',
          'Leads can manage permissions, invite codes, custom meal slots, and privacy.',
          'Kitchen recipes show shared recipes from members so they can be planned on the schedule.',
        ],
        faqs: [
          HelpFaqItem(
            question: 'What is the difference between public and private kitchen?',
            answer:
                'Private kitchens are meant to stay member-only. Public kitchens can be marked as share-friendly for broader visibility in future kitchen surfaces.',
          ),
          HelpFaqItem(
            question: 'Why do I only see some recipes in the kitchen?',
            answer:
                'Only shared recipes from kitchen members appear there. Private recipes stay hidden.',
          ),
        ],
      );
  }
}

const generalHelpFaqs = <HelpFaqItem>[
  HelpFaqItem(
    question: 'How do I get back to onboarding?',
    answer:
        'Open Settings and choose Replay Onboarding to walk through the key app features again.',
  ),
  HelpFaqItem(
    question: 'Where do I access my kitchen quickly?',
    answer:
        'Kitchen now lives in the bottom navigation so it is always one tap away.',
  ),
  HelpFaqItem(
    question: 'Why are some recipes hidden from other people?',
    answer:
        'Chefless supports private recipes, so only shared recipes are visible in kitchen and social contexts.',
  ),
];
