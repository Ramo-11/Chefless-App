import 'package:flutter_test/flutter_test.dart';
import 'package:chefless_app/models/recipe.dart';

void main() {
  final now = DateTime.utc(2026, 3, 10, 12, 0, 0);
  final later = DateTime.utc(2026, 3, 10, 13, 0, 0);

  Map<String, dynamic> sampleRecipeJson() => {
        '_id': 'recipe-123',
        'authorId': 'user-456',
        'title': 'Pasta Carbonara',
        'description': 'Classic Italian pasta',
        'story': 'My grandmother taught me this recipe',
        'photos': ['https://example.com/photo1.jpg'],
        'showSignature': true,
        'labels': ['dinner', 'quick'],
        'dietaryTags': ['dairy'],
        'cuisineTags': ['italian'],
        'difficulty': 'medium',
        'ingredients': [
          {'name': 'Spaghetti', 'quantity': 400, 'unit': 'g', 'group': 'pasta'},
          {'name': 'Eggs', 'quantity': 3, 'unit': 'pcs'},
        ],
        'steps': [
          {'order': 1, 'instruction': 'Boil water', 'photo': 'https://example.com/step1.jpg'},
          {'order': 2, 'instruction': 'Cook pasta'},
        ],
        'prepTime': 10,
        'cookTime': 20,
        'totalTime': 30,
        'servings': 4,
        'calories': 650,
        'costEstimate': 'moderate',
        'baseServings': 4,
        'forkedFrom': {
          'recipeId': 'original-recipe',
          'authorId': 'original-author',
          'authorName': 'Chef Mario',
        },
        'isModifiedFork': true,
        'isPrivate': false,
        'likesCount': 42,
        'forksCount': 5,
        'authorName': 'Test Chef',
        'authorPhoto': 'https://example.com/avatar.jpg',
        'authorSignatureUrl': 'https://example.com/signature.png',
        'isLiked': true,
        'createdAt': now.toIso8601String(),
        'updatedAt': later.toIso8601String(),
      };

  group('Ingredient', () {
    test('fromJson parses correctly', () {
      final json = {'name': 'Salt', 'quantity': 1.5, 'unit': 'tsp', 'group': 'seasoning'};
      final ingredient = Ingredient.fromJson(json);

      expect(ingredient.name, 'Salt');
      expect(ingredient.quantity, 1.5);
      expect(ingredient.unit, 'tsp');
      expect(ingredient.group, 'seasoning');
    });

    test('fromJson handles null group', () {
      final json = {'name': 'Pepper', 'quantity': 1, 'unit': 'tsp'};
      final ingredient = Ingredient.fromJson(json);

      expect(ingredient.group, isNull);
    });

    test('toJson round-trips correctly', () {
      const ingredient = Ingredient(name: 'Sugar', quantity: 2.0, unit: 'tbsp', group: 'dry');
      final json = ingredient.toJson();
      final restored = Ingredient.fromJson(json);

      expect(restored, ingredient);
    });

    test('toJson omits null group', () {
      const ingredient = Ingredient(name: 'Water', quantity: 1.0, unit: 'cup');
      final json = ingredient.toJson();

      expect(json.containsKey('group'), isFalse);
    });

    test('copyWith updates fields', () {
      const original = Ingredient(name: 'Salt', quantity: 1.0, unit: 'tsp');
      final updated = original.copyWith(quantity: 2.0, unit: 'tbsp');

      expect(updated.name, 'Salt');
      expect(updated.quantity, 2.0);
      expect(updated.unit, 'tbsp');
    });
  });

  group('RecipeStep', () {
    test('fromJson parses correctly', () {
      final json = {
        'order': 1,
        'instruction': 'Preheat oven',
        'photo': 'https://example.com/step.jpg',
      };
      final step = RecipeStep.fromJson(json);

      expect(step.order, 1);
      expect(step.instruction, 'Preheat oven');
      expect(step.photo, 'https://example.com/step.jpg');
    });

    test('fromJson handles null photo', () {
      final json = {'order': 2, 'instruction': 'Mix ingredients'};
      final step = RecipeStep.fromJson(json);

      expect(step.photo, isNull);
    });

    test('toJson round-trips correctly', () {
      const step = RecipeStep(order: 1, instruction: 'Stir');
      final json = step.toJson();
      final restored = RecipeStep.fromJson(json);

      expect(restored, step);
    });

    test('toJson omits null photo', () {
      const step = RecipeStep(order: 1, instruction: 'Stir');
      final json = step.toJson();

      expect(json.containsKey('photo'), isFalse);
    });
  });

  group('ForkSource', () {
    test('fromJson / toJson round-trips', () {
      const source = ForkSource(
        recipeId: 'r1',
        authorId: 'a1',
        authorName: 'Chef A',
      );
      final json = source.toJson();
      final restored = ForkSource.fromJson(json);

      expect(restored, source);
    });
  });

  group('Recipe', () {
    test('fromJson parses all fields correctly', () {
      final recipe = Recipe.fromJson(sampleRecipeJson());

      expect(recipe.id, 'recipe-123');
      expect(recipe.authorId, 'user-456');
      expect(recipe.title, 'Pasta Carbonara');
      expect(recipe.description, 'Classic Italian pasta');
      expect(recipe.story, 'My grandmother taught me this recipe');
      expect(recipe.photos, ['https://example.com/photo1.jpg']);
      expect(recipe.showSignature, true);
      expect(recipe.labels, ['dinner', 'quick']);
      expect(recipe.dietaryTags, ['dairy']);
      expect(recipe.cuisineTags, ['italian']);
      expect(recipe.difficulty, 'medium');
      expect(recipe.prepTime, 10);
      expect(recipe.cookTime, 20);
      expect(recipe.totalTime, 30);
      expect(recipe.servings, 4);
      expect(recipe.calories, 650);
      expect(recipe.costEstimate, 'moderate');
      expect(recipe.baseServings, 4);
      expect(recipe.isModifiedFork, true);
      expect(recipe.isPrivate, false);
      expect(recipe.likesCount, 42);
      expect(recipe.forksCount, 5);
      expect(recipe.authorName, 'Test Chef');
      expect(recipe.authorPhoto, 'https://example.com/avatar.jpg');
      expect(recipe.authorSignatureUrl, 'https://example.com/signature.png');
      expect(recipe.isLiked, true);
      expect(recipe.createdAt, now);
      expect(recipe.updatedAt, later);
    });

    test('fromJson parses nested ingredients correctly', () {
      final recipe = Recipe.fromJson(sampleRecipeJson());

      expect(recipe.ingredients, hasLength(2));
      expect(recipe.ingredients[0].name, 'Spaghetti');
      expect(recipe.ingredients[0].quantity, 400.0);
      expect(recipe.ingredients[0].unit, 'g');
      expect(recipe.ingredients[0].group, 'pasta');
      expect(recipe.ingredients[1].name, 'Eggs');
      expect(recipe.ingredients[1].group, isNull);
    });

    test('fromJson parses nested steps correctly', () {
      final recipe = Recipe.fromJson(sampleRecipeJson());

      expect(recipe.steps, hasLength(2));
      expect(recipe.steps[0].order, 1);
      expect(recipe.steps[0].instruction, 'Boil water');
      expect(recipe.steps[0].photo, 'https://example.com/step1.jpg');
      expect(recipe.steps[1].order, 2);
      expect(recipe.steps[1].photo, isNull);
    });

    test('fromJson parses forkedFrom correctly', () {
      final recipe = Recipe.fromJson(sampleRecipeJson());

      expect(recipe.forkedFrom, isNotNull);
      expect(recipe.forkedFrom!.recipeId, 'original-recipe');
      expect(recipe.forkedFrom!.authorId, 'original-author');
      expect(recipe.forkedFrom!.authorName, 'Chef Mario');
    });

    test('fromJson handles minimal data with defaults', () {
      final json = {
        '_id': 'min-recipe',
        'authorId': 'user-1',
        'title': 'Simple Recipe',
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };

      final recipe = Recipe.fromJson(json);

      expect(recipe.photos, isEmpty);
      expect(recipe.showSignature, false);
      expect(recipe.labels, isEmpty);
      expect(recipe.dietaryTags, isEmpty);
      expect(recipe.cuisineTags, isEmpty);
      expect(recipe.ingredients, isEmpty);
      expect(recipe.steps, isEmpty);
      expect(recipe.baseServings, 1);
      expect(recipe.isModifiedFork, false);
      expect(recipe.isPrivate, false);
      expect(recipe.likesCount, 0);
      expect(recipe.forksCount, 0);
      expect(recipe.forkedFrom, isNull);
      expect(recipe.authorSignatureUrl, isNull);
      expect(recipe.difficulty, isNull);
      expect(recipe.description, isNull);
    });

    test('toJson / fromJson round-trips correctly', () {
      final original = Recipe.fromJson(sampleRecipeJson());
      final json = original.toJson();
      final restored = Recipe.fromJson(json);

      expect(restored, original);
    });

    test('copyWith updates only specified fields', () {
      final original = Recipe.fromJson(sampleRecipeJson());
      final updated = original.copyWith(
        title: 'Updated Carbonara',
        likesCount: 100,
      );

      expect(updated.title, 'Updated Carbonara');
      expect(updated.likesCount, 100);
      expect(updated.id, original.id);
      expect(updated.authorId, original.authorId);
      expect(updated.ingredients, original.ingredients);
    });

    test('Equatable: same data are equal', () {
      final a = Recipe.fromJson(sampleRecipeJson());
      final b = Recipe.fromJson(sampleRecipeJson());

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('Equatable: different data are not equal', () {
      final a = Recipe.fromJson(sampleRecipeJson());
      final b = a.copyWith(title: 'Different Title');

      expect(a, isNot(b));
    });
  });
}
