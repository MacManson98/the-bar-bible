// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $CocktailsTable extends Cocktails
    with TableInfo<$CocktailsTable, Cocktail> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CocktailsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  @override
  late final GeneratedColumn<String> method = GeneratedColumn<String>(
    'method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _methodInstructionsMeta =
      const VerificationMeta('methodInstructions');
  @override
  late final GeneratedColumn<String> methodInstructions =
      GeneratedColumn<String>(
        'method_instructions',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _historyMeta = const VerificationMeta(
    'history',
  );
  @override
  late final GeneratedColumn<String> history = GeneratedColumn<String>(
    'history',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _glassMeta = const VerificationMeta('glass');
  @override
  late final GeneratedColumn<String> glass = GeneratedColumn<String>(
    'glass',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iceMeta = const VerificationMeta('ice');
  @override
  late final GeneratedColumn<String> ice = GeneratedColumn<String>(
    'ice',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _garnishMeta = const VerificationMeta(
    'garnish',
  );
  @override
  late final GeneratedColumn<String> garnish = GeneratedColumn<String>(
    'garnish',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _baseSpiritMeta = const VerificationMeta(
    'baseSpirit',
  );
  @override
  late final GeneratedColumn<String> baseSpirit = GeneratedColumn<String>(
    'base_spirit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _difficultyMeta = const VerificationMeta(
    'difficulty',
  );
  @override
  late final GeneratedColumn<int> difficulty = GeneratedColumn<int>(
    'difficulty',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    method,
    methodInstructions,
    history,
    glass,
    ice,
    garnish,
    baseSpirit,
    difficulty,
    tags,
    imagePath,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cocktails';
  @override
  VerificationContext validateIntegrity(
    Insertable<Cocktail> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('method')) {
      context.handle(
        _methodMeta,
        method.isAcceptableOrUnknown(data['method']!, _methodMeta),
      );
    } else if (isInserting) {
      context.missing(_methodMeta);
    }
    if (data.containsKey('method_instructions')) {
      context.handle(
        _methodInstructionsMeta,
        methodInstructions.isAcceptableOrUnknown(
          data['method_instructions']!,
          _methodInstructionsMeta,
        ),
      );
    }
    if (data.containsKey('history')) {
      context.handle(
        _historyMeta,
        history.isAcceptableOrUnknown(data['history']!, _historyMeta),
      );
    }
    if (data.containsKey('glass')) {
      context.handle(
        _glassMeta,
        glass.isAcceptableOrUnknown(data['glass']!, _glassMeta),
      );
    } else if (isInserting) {
      context.missing(_glassMeta);
    }
    if (data.containsKey('ice')) {
      context.handle(
        _iceMeta,
        ice.isAcceptableOrUnknown(data['ice']!, _iceMeta),
      );
    }
    if (data.containsKey('garnish')) {
      context.handle(
        _garnishMeta,
        garnish.isAcceptableOrUnknown(data['garnish']!, _garnishMeta),
      );
    }
    if (data.containsKey('base_spirit')) {
      context.handle(
        _baseSpiritMeta,
        baseSpirit.isAcceptableOrUnknown(data['base_spirit']!, _baseSpiritMeta),
      );
    } else if (isInserting) {
      context.missing(_baseSpiritMeta);
    }
    if (data.containsKey('difficulty')) {
      context.handle(
        _difficultyMeta,
        difficulty.isAcceptableOrUnknown(data['difficulty']!, _difficultyMeta),
      );
    } else if (isInserting) {
      context.missing(_difficultyMeta);
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Cocktail map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Cocktail(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      method: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}method'],
      )!,
      methodInstructions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}method_instructions'],
      ),
      history: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}history'],
      ),
      glass: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}glass'],
      )!,
      ice: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ice'],
      ),
      garnish: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}garnish'],
      ),
      baseSpirit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_spirit'],
      )!,
      difficulty: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}difficulty'],
      )!,
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      ),
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      ),
    );
  }

  @override
  $CocktailsTable createAlias(String alias) {
    return $CocktailsTable(attachedDatabase, alias);
  }
}

class Cocktail extends DataClass implements Insertable<Cocktail> {
  final int id;
  final String name;
  final String? description;
  final String method;
  final String? methodInstructions;
  final String? history;
  final String glass;
  final String? ice;
  final String? garnish;
  final String baseSpirit;
  final int difficulty;
  final String? tags;
  final String? imagePath;
  const Cocktail({
    required this.id,
    required this.name,
    this.description,
    required this.method,
    this.methodInstructions,
    this.history,
    required this.glass,
    this.ice,
    this.garnish,
    required this.baseSpirit,
    required this.difficulty,
    this.tags,
    this.imagePath,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['method'] = Variable<String>(method);
    if (!nullToAbsent || methodInstructions != null) {
      map['method_instructions'] = Variable<String>(methodInstructions);
    }
    if (!nullToAbsent || history != null) {
      map['history'] = Variable<String>(history);
    }
    map['glass'] = Variable<String>(glass);
    if (!nullToAbsent || ice != null) {
      map['ice'] = Variable<String>(ice);
    }
    if (!nullToAbsent || garnish != null) {
      map['garnish'] = Variable<String>(garnish);
    }
    map['base_spirit'] = Variable<String>(baseSpirit);
    map['difficulty'] = Variable<int>(difficulty);
    if (!nullToAbsent || tags != null) {
      map['tags'] = Variable<String>(tags);
    }
    if (!nullToAbsent || imagePath != null) {
      map['image_path'] = Variable<String>(imagePath);
    }
    return map;
  }

  CocktailsCompanion toCompanion(bool nullToAbsent) {
    return CocktailsCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      method: Value(method),
      methodInstructions: methodInstructions == null && nullToAbsent
          ? const Value.absent()
          : Value(methodInstructions),
      history: history == null && nullToAbsent
          ? const Value.absent()
          : Value(history),
      glass: Value(glass),
      ice: ice == null && nullToAbsent ? const Value.absent() : Value(ice),
      garnish: garnish == null && nullToAbsent
          ? const Value.absent()
          : Value(garnish),
      baseSpirit: Value(baseSpirit),
      difficulty: Value(difficulty),
      tags: tags == null && nullToAbsent ? const Value.absent() : Value(tags),
      imagePath: imagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(imagePath),
    );
  }

  factory Cocktail.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Cocktail(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      method: serializer.fromJson<String>(json['method']),
      methodInstructions: serializer.fromJson<String?>(
        json['methodInstructions'],
      ),
      history: serializer.fromJson<String?>(json['history']),
      glass: serializer.fromJson<String>(json['glass']),
      ice: serializer.fromJson<String?>(json['ice']),
      garnish: serializer.fromJson<String?>(json['garnish']),
      baseSpirit: serializer.fromJson<String>(json['baseSpirit']),
      difficulty: serializer.fromJson<int>(json['difficulty']),
      tags: serializer.fromJson<String?>(json['tags']),
      imagePath: serializer.fromJson<String?>(json['imagePath']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'method': serializer.toJson<String>(method),
      'methodInstructions': serializer.toJson<String?>(methodInstructions),
      'history': serializer.toJson<String?>(history),
      'glass': serializer.toJson<String>(glass),
      'ice': serializer.toJson<String?>(ice),
      'garnish': serializer.toJson<String?>(garnish),
      'baseSpirit': serializer.toJson<String>(baseSpirit),
      'difficulty': serializer.toJson<int>(difficulty),
      'tags': serializer.toJson<String?>(tags),
      'imagePath': serializer.toJson<String?>(imagePath),
    };
  }

  Cocktail copyWith({
    int? id,
    String? name,
    Value<String?> description = const Value.absent(),
    String? method,
    Value<String?> methodInstructions = const Value.absent(),
    Value<String?> history = const Value.absent(),
    String? glass,
    Value<String?> ice = const Value.absent(),
    Value<String?> garnish = const Value.absent(),
    String? baseSpirit,
    int? difficulty,
    Value<String?> tags = const Value.absent(),
    Value<String?> imagePath = const Value.absent(),
  }) => Cocktail(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    method: method ?? this.method,
    methodInstructions: methodInstructions.present
        ? methodInstructions.value
        : this.methodInstructions,
    history: history.present ? history.value : this.history,
    glass: glass ?? this.glass,
    ice: ice.present ? ice.value : this.ice,
    garnish: garnish.present ? garnish.value : this.garnish,
    baseSpirit: baseSpirit ?? this.baseSpirit,
    difficulty: difficulty ?? this.difficulty,
    tags: tags.present ? tags.value : this.tags,
    imagePath: imagePath.present ? imagePath.value : this.imagePath,
  );
  Cocktail copyWithCompanion(CocktailsCompanion data) {
    return Cocktail(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      method: data.method.present ? data.method.value : this.method,
      methodInstructions: data.methodInstructions.present
          ? data.methodInstructions.value
          : this.methodInstructions,
      history: data.history.present ? data.history.value : this.history,
      glass: data.glass.present ? data.glass.value : this.glass,
      ice: data.ice.present ? data.ice.value : this.ice,
      garnish: data.garnish.present ? data.garnish.value : this.garnish,
      baseSpirit: data.baseSpirit.present
          ? data.baseSpirit.value
          : this.baseSpirit,
      difficulty: data.difficulty.present
          ? data.difficulty.value
          : this.difficulty,
      tags: data.tags.present ? data.tags.value : this.tags,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Cocktail(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('method: $method, ')
          ..write('methodInstructions: $methodInstructions, ')
          ..write('history: $history, ')
          ..write('glass: $glass, ')
          ..write('ice: $ice, ')
          ..write('garnish: $garnish, ')
          ..write('baseSpirit: $baseSpirit, ')
          ..write('difficulty: $difficulty, ')
          ..write('tags: $tags, ')
          ..write('imagePath: $imagePath')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    method,
    methodInstructions,
    history,
    glass,
    ice,
    garnish,
    baseSpirit,
    difficulty,
    tags,
    imagePath,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Cocktail &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.method == this.method &&
          other.methodInstructions == this.methodInstructions &&
          other.history == this.history &&
          other.glass == this.glass &&
          other.ice == this.ice &&
          other.garnish == this.garnish &&
          other.baseSpirit == this.baseSpirit &&
          other.difficulty == this.difficulty &&
          other.tags == this.tags &&
          other.imagePath == this.imagePath);
}

class CocktailsCompanion extends UpdateCompanion<Cocktail> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<String> method;
  final Value<String?> methodInstructions;
  final Value<String?> history;
  final Value<String> glass;
  final Value<String?> ice;
  final Value<String?> garnish;
  final Value<String> baseSpirit;
  final Value<int> difficulty;
  final Value<String?> tags;
  final Value<String?> imagePath;
  const CocktailsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.method = const Value.absent(),
    this.methodInstructions = const Value.absent(),
    this.history = const Value.absent(),
    this.glass = const Value.absent(),
    this.ice = const Value.absent(),
    this.garnish = const Value.absent(),
    this.baseSpirit = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.tags = const Value.absent(),
    this.imagePath = const Value.absent(),
  });
  CocktailsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.description = const Value.absent(),
    required String method,
    this.methodInstructions = const Value.absent(),
    this.history = const Value.absent(),
    required String glass,
    this.ice = const Value.absent(),
    this.garnish = const Value.absent(),
    required String baseSpirit,
    required int difficulty,
    this.tags = const Value.absent(),
    this.imagePath = const Value.absent(),
  }) : name = Value(name),
       method = Value(method),
       glass = Value(glass),
       baseSpirit = Value(baseSpirit),
       difficulty = Value(difficulty);
  static Insertable<Cocktail> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? method,
    Expression<String>? methodInstructions,
    Expression<String>? history,
    Expression<String>? glass,
    Expression<String>? ice,
    Expression<String>? garnish,
    Expression<String>? baseSpirit,
    Expression<int>? difficulty,
    Expression<String>? tags,
    Expression<String>? imagePath,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (method != null) 'method': method,
      if (methodInstructions != null) 'method_instructions': methodInstructions,
      if (history != null) 'history': history,
      if (glass != null) 'glass': glass,
      if (ice != null) 'ice': ice,
      if (garnish != null) 'garnish': garnish,
      if (baseSpirit != null) 'base_spirit': baseSpirit,
      if (difficulty != null) 'difficulty': difficulty,
      if (tags != null) 'tags': tags,
      if (imagePath != null) 'image_path': imagePath,
    });
  }

  CocktailsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? description,
    Value<String>? method,
    Value<String?>? methodInstructions,
    Value<String?>? history,
    Value<String>? glass,
    Value<String?>? ice,
    Value<String?>? garnish,
    Value<String>? baseSpirit,
    Value<int>? difficulty,
    Value<String?>? tags,
    Value<String?>? imagePath,
  }) {
    return CocktailsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      method: method ?? this.method,
      methodInstructions: methodInstructions ?? this.methodInstructions,
      history: history ?? this.history,
      glass: glass ?? this.glass,
      ice: ice ?? this.ice,
      garnish: garnish ?? this.garnish,
      baseSpirit: baseSpirit ?? this.baseSpirit,
      difficulty: difficulty ?? this.difficulty,
      tags: tags ?? this.tags,
      imagePath: imagePath ?? this.imagePath,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (method.present) {
      map['method'] = Variable<String>(method.value);
    }
    if (methodInstructions.present) {
      map['method_instructions'] = Variable<String>(methodInstructions.value);
    }
    if (history.present) {
      map['history'] = Variable<String>(history.value);
    }
    if (glass.present) {
      map['glass'] = Variable<String>(glass.value);
    }
    if (ice.present) {
      map['ice'] = Variable<String>(ice.value);
    }
    if (garnish.present) {
      map['garnish'] = Variable<String>(garnish.value);
    }
    if (baseSpirit.present) {
      map['base_spirit'] = Variable<String>(baseSpirit.value);
    }
    if (difficulty.present) {
      map['difficulty'] = Variable<int>(difficulty.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CocktailsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('method: $method, ')
          ..write('methodInstructions: $methodInstructions, ')
          ..write('history: $history, ')
          ..write('glass: $glass, ')
          ..write('ice: $ice, ')
          ..write('garnish: $garnish, ')
          ..write('baseSpirit: $baseSpirit, ')
          ..write('difficulty: $difficulty, ')
          ..write('tags: $tags, ')
          ..write('imagePath: $imagePath')
          ..write(')'))
        .toString();
  }
}

class $IngredientsTable extends Ingredients
    with TableInfo<$IngredientsTable, Ingredient> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IngredientsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Other'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, category];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ingredients';
  @override
  VerificationContext validateIntegrity(
    Insertable<Ingredient> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Ingredient map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Ingredient(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
    );
  }

  @override
  $IngredientsTable createAlias(String alias) {
    return $IngredientsTable(attachedDatabase, alias);
  }
}

class Ingredient extends DataClass implements Insertable<Ingredient> {
  final int id;
  final String name;
  final String category;
  const Ingredient({
    required this.id,
    required this.name,
    required this.category,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['category'] = Variable<String>(category);
    return map;
  }

  IngredientsCompanion toCompanion(bool nullToAbsent) {
    return IngredientsCompanion(
      id: Value(id),
      name: Value(name),
      category: Value(category),
    );
  }

  factory Ingredient.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Ingredient(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      category: serializer.fromJson<String>(json['category']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'category': serializer.toJson<String>(category),
    };
  }

  Ingredient copyWith({int? id, String? name, String? category}) => Ingredient(
    id: id ?? this.id,
    name: name ?? this.name,
    category: category ?? this.category,
  );
  Ingredient copyWithCompanion(IngredientsCompanion data) {
    return Ingredient(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      category: data.category.present ? data.category.value : this.category,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Ingredient(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, category);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Ingredient &&
          other.id == this.id &&
          other.name == this.name &&
          other.category == this.category);
}

class IngredientsCompanion extends UpdateCompanion<Ingredient> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> category;
  const IngredientsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.category = const Value.absent(),
  });
  IngredientsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.category = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Ingredient> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? category,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (category != null) 'category': category,
    });
  }

  IngredientsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? category,
  }) {
    return IngredientsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IngredientsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category')
          ..write(')'))
        .toString();
  }
}

class $CocktailIngredientsTable extends CocktailIngredients
    with TableInfo<$CocktailIngredientsTable, CocktailIngredient> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CocktailIngredientsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _cocktailIdMeta = const VerificationMeta(
    'cocktailId',
  );
  @override
  late final GeneratedColumn<int> cocktailId = GeneratedColumn<int>(
    'cocktail_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cocktails (id)',
    ),
  );
  static const VerificationMeta _ingredientIdMeta = const VerificationMeta(
    'ingredientId',
  );
  @override
  late final GeneratedColumn<int> ingredientId = GeneratedColumn<int>(
    'ingredient_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES ingredients (id)',
    ),
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _prepNoteMeta = const VerificationMeta(
    'prepNote',
  );
  @override
  late final GeneratedColumn<String> prepNote = GeneratedColumn<String>(
    'prep_note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    cocktailId,
    ingredientId,
    amount,
    unit,
    prepNote,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cocktail_ingredients';
  @override
  VerificationContext validateIntegrity(
    Insertable<CocktailIngredient> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('cocktail_id')) {
      context.handle(
        _cocktailIdMeta,
        cocktailId.isAcceptableOrUnknown(data['cocktail_id']!, _cocktailIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cocktailIdMeta);
    }
    if (data.containsKey('ingredient_id')) {
      context.handle(
        _ingredientIdMeta,
        ingredientId.isAcceptableOrUnknown(
          data['ingredient_id']!,
          _ingredientIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ingredientIdMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    } else if (isInserting) {
      context.missing(_unitMeta);
    }
    if (data.containsKey('prep_note')) {
      context.handle(
        _prepNoteMeta,
        prepNote.isAcceptableOrUnknown(data['prep_note']!, _prepNoteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CocktailIngredient map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CocktailIngredient(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      cocktailId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cocktail_id'],
      )!,
      ingredientId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ingredient_id'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      )!,
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      )!,
      prepNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prep_note'],
      ),
    );
  }

  @override
  $CocktailIngredientsTable createAlias(String alias) {
    return $CocktailIngredientsTable(attachedDatabase, alias);
  }
}

class CocktailIngredient extends DataClass
    implements Insertable<CocktailIngredient> {
  final int id;
  final int cocktailId;
  final int ingredientId;
  final double amount;
  final String unit;
  final String? prepNote;
  const CocktailIngredient({
    required this.id,
    required this.cocktailId,
    required this.ingredientId,
    required this.amount,
    required this.unit,
    this.prepNote,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['cocktail_id'] = Variable<int>(cocktailId);
    map['ingredient_id'] = Variable<int>(ingredientId);
    map['amount'] = Variable<double>(amount);
    map['unit'] = Variable<String>(unit);
    if (!nullToAbsent || prepNote != null) {
      map['prep_note'] = Variable<String>(prepNote);
    }
    return map;
  }

  CocktailIngredientsCompanion toCompanion(bool nullToAbsent) {
    return CocktailIngredientsCompanion(
      id: Value(id),
      cocktailId: Value(cocktailId),
      ingredientId: Value(ingredientId),
      amount: Value(amount),
      unit: Value(unit),
      prepNote: prepNote == null && nullToAbsent
          ? const Value.absent()
          : Value(prepNote),
    );
  }

  factory CocktailIngredient.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CocktailIngredient(
      id: serializer.fromJson<int>(json['id']),
      cocktailId: serializer.fromJson<int>(json['cocktailId']),
      ingredientId: serializer.fromJson<int>(json['ingredientId']),
      amount: serializer.fromJson<double>(json['amount']),
      unit: serializer.fromJson<String>(json['unit']),
      prepNote: serializer.fromJson<String?>(json['prepNote']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'cocktailId': serializer.toJson<int>(cocktailId),
      'ingredientId': serializer.toJson<int>(ingredientId),
      'amount': serializer.toJson<double>(amount),
      'unit': serializer.toJson<String>(unit),
      'prepNote': serializer.toJson<String?>(prepNote),
    };
  }

  CocktailIngredient copyWith({
    int? id,
    int? cocktailId,
    int? ingredientId,
    double? amount,
    String? unit,
    Value<String?> prepNote = const Value.absent(),
  }) => CocktailIngredient(
    id: id ?? this.id,
    cocktailId: cocktailId ?? this.cocktailId,
    ingredientId: ingredientId ?? this.ingredientId,
    amount: amount ?? this.amount,
    unit: unit ?? this.unit,
    prepNote: prepNote.present ? prepNote.value : this.prepNote,
  );
  CocktailIngredient copyWithCompanion(CocktailIngredientsCompanion data) {
    return CocktailIngredient(
      id: data.id.present ? data.id.value : this.id,
      cocktailId: data.cocktailId.present
          ? data.cocktailId.value
          : this.cocktailId,
      ingredientId: data.ingredientId.present
          ? data.ingredientId.value
          : this.ingredientId,
      amount: data.amount.present ? data.amount.value : this.amount,
      unit: data.unit.present ? data.unit.value : this.unit,
      prepNote: data.prepNote.present ? data.prepNote.value : this.prepNote,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CocktailIngredient(')
          ..write('id: $id, ')
          ..write('cocktailId: $cocktailId, ')
          ..write('ingredientId: $ingredientId, ')
          ..write('amount: $amount, ')
          ..write('unit: $unit, ')
          ..write('prepNote: $prepNote')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, cocktailId, ingredientId, amount, unit, prepNote);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CocktailIngredient &&
          other.id == this.id &&
          other.cocktailId == this.cocktailId &&
          other.ingredientId == this.ingredientId &&
          other.amount == this.amount &&
          other.unit == this.unit &&
          other.prepNote == this.prepNote);
}

class CocktailIngredientsCompanion extends UpdateCompanion<CocktailIngredient> {
  final Value<int> id;
  final Value<int> cocktailId;
  final Value<int> ingredientId;
  final Value<double> amount;
  final Value<String> unit;
  final Value<String?> prepNote;
  const CocktailIngredientsCompanion({
    this.id = const Value.absent(),
    this.cocktailId = const Value.absent(),
    this.ingredientId = const Value.absent(),
    this.amount = const Value.absent(),
    this.unit = const Value.absent(),
    this.prepNote = const Value.absent(),
  });
  CocktailIngredientsCompanion.insert({
    this.id = const Value.absent(),
    required int cocktailId,
    required int ingredientId,
    required double amount,
    required String unit,
    this.prepNote = const Value.absent(),
  }) : cocktailId = Value(cocktailId),
       ingredientId = Value(ingredientId),
       amount = Value(amount),
       unit = Value(unit);
  static Insertable<CocktailIngredient> custom({
    Expression<int>? id,
    Expression<int>? cocktailId,
    Expression<int>? ingredientId,
    Expression<double>? amount,
    Expression<String>? unit,
    Expression<String>? prepNote,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cocktailId != null) 'cocktail_id': cocktailId,
      if (ingredientId != null) 'ingredient_id': ingredientId,
      if (amount != null) 'amount': amount,
      if (unit != null) 'unit': unit,
      if (prepNote != null) 'prep_note': prepNote,
    });
  }

  CocktailIngredientsCompanion copyWith({
    Value<int>? id,
    Value<int>? cocktailId,
    Value<int>? ingredientId,
    Value<double>? amount,
    Value<String>? unit,
    Value<String?>? prepNote,
  }) {
    return CocktailIngredientsCompanion(
      id: id ?? this.id,
      cocktailId: cocktailId ?? this.cocktailId,
      ingredientId: ingredientId ?? this.ingredientId,
      amount: amount ?? this.amount,
      unit: unit ?? this.unit,
      prepNote: prepNote ?? this.prepNote,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (cocktailId.present) {
      map['cocktail_id'] = Variable<int>(cocktailId.value);
    }
    if (ingredientId.present) {
      map['ingredient_id'] = Variable<int>(ingredientId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (prepNote.present) {
      map['prep_note'] = Variable<String>(prepNote.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CocktailIngredientsCompanion(')
          ..write('id: $id, ')
          ..write('cocktailId: $cocktailId, ')
          ..write('ingredientId: $ingredientId, ')
          ..write('amount: $amount, ')
          ..write('unit: $unit, ')
          ..write('prepNote: $prepNote')
          ..write(')'))
        .toString();
  }
}

class $CollectionsTable extends Collections
    with TableInfo<$CollectionsTable, Collection> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CollectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, description, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'collections';
  @override
  VerificationContext validateIntegrity(
    Insertable<Collection> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Collection map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Collection(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CollectionsTable createAlias(String alias) {
    return $CollectionsTable(attachedDatabase, alias);
  }
}

class Collection extends DataClass implements Insertable<Collection> {
  final int id;
  final String name;
  final String? description;
  final DateTime createdAt;
  const Collection({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CollectionsCompanion toCompanion(bool nullToAbsent) {
    return CollectionsCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      createdAt: Value(createdAt),
    );
  }

  factory Collection.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Collection(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Collection copyWith({
    int? id,
    String? name,
    Value<String?> description = const Value.absent(),
    DateTime? createdAt,
  }) => Collection(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    createdAt: createdAt ?? this.createdAt,
  );
  Collection copyWithCompanion(CollectionsCompanion data) {
    return Collection(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Collection(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, description, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Collection &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.createdAt == this.createdAt);
}

class CollectionsCompanion extends UpdateCompanion<Collection> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<DateTime> createdAt;
  const CollectionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  CollectionsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.description = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Collection> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  CollectionsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? description,
    Value<DateTime>? createdAt,
  }) {
    return CollectionsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CollectionsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $CollectionCocktailsTable extends CollectionCocktails
    with TableInfo<$CollectionCocktailsTable, CollectionCocktail> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CollectionCocktailsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _collectionIdMeta = const VerificationMeta(
    'collectionId',
  );
  @override
  late final GeneratedColumn<int> collectionId = GeneratedColumn<int>(
    'collection_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES collections (id)',
    ),
  );
  static const VerificationMeta _cocktailIdMeta = const VerificationMeta(
    'cocktailId',
  );
  @override
  late final GeneratedColumn<int> cocktailId = GeneratedColumn<int>(
    'cocktail_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cocktails (id)',
    ),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, collectionId, cocktailId, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'collection_cocktails';
  @override
  VerificationContext validateIntegrity(
    Insertable<CollectionCocktail> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('collection_id')) {
      context.handle(
        _collectionIdMeta,
        collectionId.isAcceptableOrUnknown(
          data['collection_id']!,
          _collectionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_collectionIdMeta);
    }
    if (data.containsKey('cocktail_id')) {
      context.handle(
        _cocktailIdMeta,
        cocktailId.isAcceptableOrUnknown(data['cocktail_id']!, _cocktailIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cocktailIdMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CollectionCocktail map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CollectionCocktail(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      collectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}collection_id'],
      )!,
      cocktailId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cocktail_id'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $CollectionCocktailsTable createAlias(String alias) {
    return $CollectionCocktailsTable(attachedDatabase, alias);
  }
}

class CollectionCocktail extends DataClass
    implements Insertable<CollectionCocktail> {
  final int id;
  final int collectionId;
  final int cocktailId;
  final DateTime addedAt;
  const CollectionCocktail({
    required this.id,
    required this.collectionId,
    required this.cocktailId,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['collection_id'] = Variable<int>(collectionId);
    map['cocktail_id'] = Variable<int>(cocktailId);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  CollectionCocktailsCompanion toCompanion(bool nullToAbsent) {
    return CollectionCocktailsCompanion(
      id: Value(id),
      collectionId: Value(collectionId),
      cocktailId: Value(cocktailId),
      addedAt: Value(addedAt),
    );
  }

  factory CollectionCocktail.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CollectionCocktail(
      id: serializer.fromJson<int>(json['id']),
      collectionId: serializer.fromJson<int>(json['collectionId']),
      cocktailId: serializer.fromJson<int>(json['cocktailId']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'collectionId': serializer.toJson<int>(collectionId),
      'cocktailId': serializer.toJson<int>(cocktailId),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  CollectionCocktail copyWith({
    int? id,
    int? collectionId,
    int? cocktailId,
    DateTime? addedAt,
  }) => CollectionCocktail(
    id: id ?? this.id,
    collectionId: collectionId ?? this.collectionId,
    cocktailId: cocktailId ?? this.cocktailId,
    addedAt: addedAt ?? this.addedAt,
  );
  CollectionCocktail copyWithCompanion(CollectionCocktailsCompanion data) {
    return CollectionCocktail(
      id: data.id.present ? data.id.value : this.id,
      collectionId: data.collectionId.present
          ? data.collectionId.value
          : this.collectionId,
      cocktailId: data.cocktailId.present
          ? data.cocktailId.value
          : this.cocktailId,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CollectionCocktail(')
          ..write('id: $id, ')
          ..write('collectionId: $collectionId, ')
          ..write('cocktailId: $cocktailId, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, collectionId, cocktailId, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CollectionCocktail &&
          other.id == this.id &&
          other.collectionId == this.collectionId &&
          other.cocktailId == this.cocktailId &&
          other.addedAt == this.addedAt);
}

class CollectionCocktailsCompanion extends UpdateCompanion<CollectionCocktail> {
  final Value<int> id;
  final Value<int> collectionId;
  final Value<int> cocktailId;
  final Value<DateTime> addedAt;
  const CollectionCocktailsCompanion({
    this.id = const Value.absent(),
    this.collectionId = const Value.absent(),
    this.cocktailId = const Value.absent(),
    this.addedAt = const Value.absent(),
  });
  CollectionCocktailsCompanion.insert({
    this.id = const Value.absent(),
    required int collectionId,
    required int cocktailId,
    this.addedAt = const Value.absent(),
  }) : collectionId = Value(collectionId),
       cocktailId = Value(cocktailId);
  static Insertable<CollectionCocktail> custom({
    Expression<int>? id,
    Expression<int>? collectionId,
    Expression<int>? cocktailId,
    Expression<DateTime>? addedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (collectionId != null) 'collection_id': collectionId,
      if (cocktailId != null) 'cocktail_id': cocktailId,
      if (addedAt != null) 'added_at': addedAt,
    });
  }

  CollectionCocktailsCompanion copyWith({
    Value<int>? id,
    Value<int>? collectionId,
    Value<int>? cocktailId,
    Value<DateTime>? addedAt,
  }) {
    return CollectionCocktailsCompanion(
      id: id ?? this.id,
      collectionId: collectionId ?? this.collectionId,
      cocktailId: cocktailId ?? this.cocktailId,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (collectionId.present) {
      map['collection_id'] = Variable<int>(collectionId.value);
    }
    if (cocktailId.present) {
      map['cocktail_id'] = Variable<int>(cocktailId.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CollectionCocktailsCompanion(')
          ..write('id: $id, ')
          ..write('collectionId: $collectionId, ')
          ..write('cocktailId: $cocktailId, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }
}

class $SavedBarsTable extends SavedBars
    with TableInfo<$SavedBarsTable, SavedBar> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedBarsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _lastUsedMeta = const VerificationMeta(
    'lastUsed',
  );
  @override
  late final GeneratedColumn<DateTime> lastUsed = GeneratedColumn<DateTime>(
    'last_used',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    isDefault,
    createdAt,
    lastUsed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_bars';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedBar> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('last_used')) {
      context.handle(
        _lastUsedMeta,
        lastUsed.isAcceptableOrUnknown(data['last_used']!, _lastUsedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SavedBar map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedBar(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastUsed: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_used'],
      )!,
    );
  }

  @override
  $SavedBarsTable createAlias(String alias) {
    return $SavedBarsTable(attachedDatabase, alias);
  }
}

class SavedBar extends DataClass implements Insertable<SavedBar> {
  final int id;
  final String name;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime lastUsed;
  const SavedBar({
    required this.id,
    required this.name,
    required this.isDefault,
    required this.createdAt,
    required this.lastUsed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['is_default'] = Variable<bool>(isDefault);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['last_used'] = Variable<DateTime>(lastUsed);
    return map;
  }

  SavedBarsCompanion toCompanion(bool nullToAbsent) {
    return SavedBarsCompanion(
      id: Value(id),
      name: Value(name),
      isDefault: Value(isDefault),
      createdAt: Value(createdAt),
      lastUsed: Value(lastUsed),
    );
  }

  factory SavedBar.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedBar(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastUsed: serializer.fromJson<DateTime>(json['lastUsed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'isDefault': serializer.toJson<bool>(isDefault),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastUsed': serializer.toJson<DateTime>(lastUsed),
    };
  }

  SavedBar copyWith({
    int? id,
    String? name,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? lastUsed,
  }) => SavedBar(
    id: id ?? this.id,
    name: name ?? this.name,
    isDefault: isDefault ?? this.isDefault,
    createdAt: createdAt ?? this.createdAt,
    lastUsed: lastUsed ?? this.lastUsed,
  );
  SavedBar copyWithCompanion(SavedBarsCompanion data) {
    return SavedBar(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastUsed: data.lastUsed.present ? data.lastUsed.value : this.lastUsed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedBar(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('isDefault: $isDefault, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastUsed: $lastUsed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, isDefault, createdAt, lastUsed);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedBar &&
          other.id == this.id &&
          other.name == this.name &&
          other.isDefault == this.isDefault &&
          other.createdAt == this.createdAt &&
          other.lastUsed == this.lastUsed);
}

class SavedBarsCompanion extends UpdateCompanion<SavedBar> {
  final Value<int> id;
  final Value<String> name;
  final Value<bool> isDefault;
  final Value<DateTime> createdAt;
  final Value<DateTime> lastUsed;
  const SavedBarsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastUsed = const Value.absent(),
  });
  SavedBarsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.isDefault = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastUsed = const Value.absent(),
  }) : name = Value(name);
  static Insertable<SavedBar> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<bool>? isDefault,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastUsed,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (isDefault != null) 'is_default': isDefault,
      if (createdAt != null) 'created_at': createdAt,
      if (lastUsed != null) 'last_used': lastUsed,
    });
  }

  SavedBarsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<bool>? isDefault,
    Value<DateTime>? createdAt,
    Value<DateTime>? lastUsed,
  }) {
    return SavedBarsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastUsed.present) {
      map['last_used'] = Variable<DateTime>(lastUsed.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedBarsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('isDefault: $isDefault, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastUsed: $lastUsed')
          ..write(')'))
        .toString();
  }
}

class $SavedBarIngredientsTable extends SavedBarIngredients
    with TableInfo<$SavedBarIngredientsTable, SavedBarIngredient> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedBarIngredientsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _savedBarIdMeta = const VerificationMeta(
    'savedBarId',
  );
  @override
  late final GeneratedColumn<int> savedBarId = GeneratedColumn<int>(
    'saved_bar_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES saved_bars (id)',
    ),
  );
  static const VerificationMeta _ingredientIdMeta = const VerificationMeta(
    'ingredientId',
  );
  @override
  late final GeneratedColumn<int> ingredientId = GeneratedColumn<int>(
    'ingredient_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES ingredients (id)',
    ),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, savedBarId, ingredientId, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_bar_ingredients';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedBarIngredient> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('saved_bar_id')) {
      context.handle(
        _savedBarIdMeta,
        savedBarId.isAcceptableOrUnknown(
          data['saved_bar_id']!,
          _savedBarIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_savedBarIdMeta);
    }
    if (data.containsKey('ingredient_id')) {
      context.handle(
        _ingredientIdMeta,
        ingredientId.isAcceptableOrUnknown(
          data['ingredient_id']!,
          _ingredientIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ingredientIdMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SavedBarIngredient map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedBarIngredient(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      savedBarId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}saved_bar_id'],
      )!,
      ingredientId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ingredient_id'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $SavedBarIngredientsTable createAlias(String alias) {
    return $SavedBarIngredientsTable(attachedDatabase, alias);
  }
}

class SavedBarIngredient extends DataClass
    implements Insertable<SavedBarIngredient> {
  final int id;
  final int savedBarId;
  final int ingredientId;
  final DateTime addedAt;
  const SavedBarIngredient({
    required this.id,
    required this.savedBarId,
    required this.ingredientId,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['saved_bar_id'] = Variable<int>(savedBarId);
    map['ingredient_id'] = Variable<int>(ingredientId);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  SavedBarIngredientsCompanion toCompanion(bool nullToAbsent) {
    return SavedBarIngredientsCompanion(
      id: Value(id),
      savedBarId: Value(savedBarId),
      ingredientId: Value(ingredientId),
      addedAt: Value(addedAt),
    );
  }

  factory SavedBarIngredient.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedBarIngredient(
      id: serializer.fromJson<int>(json['id']),
      savedBarId: serializer.fromJson<int>(json['savedBarId']),
      ingredientId: serializer.fromJson<int>(json['ingredientId']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'savedBarId': serializer.toJson<int>(savedBarId),
      'ingredientId': serializer.toJson<int>(ingredientId),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  SavedBarIngredient copyWith({
    int? id,
    int? savedBarId,
    int? ingredientId,
    DateTime? addedAt,
  }) => SavedBarIngredient(
    id: id ?? this.id,
    savedBarId: savedBarId ?? this.savedBarId,
    ingredientId: ingredientId ?? this.ingredientId,
    addedAt: addedAt ?? this.addedAt,
  );
  SavedBarIngredient copyWithCompanion(SavedBarIngredientsCompanion data) {
    return SavedBarIngredient(
      id: data.id.present ? data.id.value : this.id,
      savedBarId: data.savedBarId.present
          ? data.savedBarId.value
          : this.savedBarId,
      ingredientId: data.ingredientId.present
          ? data.ingredientId.value
          : this.ingredientId,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedBarIngredient(')
          ..write('id: $id, ')
          ..write('savedBarId: $savedBarId, ')
          ..write('ingredientId: $ingredientId, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, savedBarId, ingredientId, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedBarIngredient &&
          other.id == this.id &&
          other.savedBarId == this.savedBarId &&
          other.ingredientId == this.ingredientId &&
          other.addedAt == this.addedAt);
}

class SavedBarIngredientsCompanion extends UpdateCompanion<SavedBarIngredient> {
  final Value<int> id;
  final Value<int> savedBarId;
  final Value<int> ingredientId;
  final Value<DateTime> addedAt;
  const SavedBarIngredientsCompanion({
    this.id = const Value.absent(),
    this.savedBarId = const Value.absent(),
    this.ingredientId = const Value.absent(),
    this.addedAt = const Value.absent(),
  });
  SavedBarIngredientsCompanion.insert({
    this.id = const Value.absent(),
    required int savedBarId,
    required int ingredientId,
    this.addedAt = const Value.absent(),
  }) : savedBarId = Value(savedBarId),
       ingredientId = Value(ingredientId);
  static Insertable<SavedBarIngredient> custom({
    Expression<int>? id,
    Expression<int>? savedBarId,
    Expression<int>? ingredientId,
    Expression<DateTime>? addedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (savedBarId != null) 'saved_bar_id': savedBarId,
      if (ingredientId != null) 'ingredient_id': ingredientId,
      if (addedAt != null) 'added_at': addedAt,
    });
  }

  SavedBarIngredientsCompanion copyWith({
    Value<int>? id,
    Value<int>? savedBarId,
    Value<int>? ingredientId,
    Value<DateTime>? addedAt,
  }) {
    return SavedBarIngredientsCompanion(
      id: id ?? this.id,
      savedBarId: savedBarId ?? this.savedBarId,
      ingredientId: ingredientId ?? this.ingredientId,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (savedBarId.present) {
      map['saved_bar_id'] = Variable<int>(savedBarId.value);
    }
    if (ingredientId.present) {
      map['ingredient_id'] = Variable<int>(ingredientId.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedBarIngredientsCompanion(')
          ..write('id: $id, ')
          ..write('savedBarId: $savedBarId, ')
          ..write('ingredientId: $ingredientId, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }
}

class $ShoppingListTable extends ShoppingList
    with TableInfo<$ShoppingListTable, ShoppingListData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShoppingListTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _ingredientIdMeta = const VerificationMeta(
    'ingredientId',
  );
  @override
  late final GeneratedColumn<int> ingredientId = GeneratedColumn<int>(
    'ingredient_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES ingredients (id)',
    ),
  );
  static const VerificationMeta _unlocksCountMeta = const VerificationMeta(
    'unlocksCount',
  );
  @override
  late final GeneratedColumn<int> unlocksCount = GeneratedColumn<int>(
    'unlocks_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ingredientId,
    unlocksCount,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shopping_list';
  @override
  VerificationContext validateIntegrity(
    Insertable<ShoppingListData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('ingredient_id')) {
      context.handle(
        _ingredientIdMeta,
        ingredientId.isAcceptableOrUnknown(
          data['ingredient_id']!,
          _ingredientIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ingredientIdMeta);
    }
    if (data.containsKey('unlocks_count')) {
      context.handle(
        _unlocksCountMeta,
        unlocksCount.isAcceptableOrUnknown(
          data['unlocks_count']!,
          _unlocksCountMeta,
        ),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ShoppingListData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShoppingListData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      ingredientId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ingredient_id'],
      )!,
      unlocksCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unlocks_count'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $ShoppingListTable createAlias(String alias) {
    return $ShoppingListTable(attachedDatabase, alias);
  }
}

class ShoppingListData extends DataClass
    implements Insertable<ShoppingListData> {
  final int id;
  final int ingredientId;
  final int unlocksCount;
  final DateTime addedAt;
  const ShoppingListData({
    required this.id,
    required this.ingredientId,
    required this.unlocksCount,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['ingredient_id'] = Variable<int>(ingredientId);
    map['unlocks_count'] = Variable<int>(unlocksCount);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  ShoppingListCompanion toCompanion(bool nullToAbsent) {
    return ShoppingListCompanion(
      id: Value(id),
      ingredientId: Value(ingredientId),
      unlocksCount: Value(unlocksCount),
      addedAt: Value(addedAt),
    );
  }

  factory ShoppingListData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShoppingListData(
      id: serializer.fromJson<int>(json['id']),
      ingredientId: serializer.fromJson<int>(json['ingredientId']),
      unlocksCount: serializer.fromJson<int>(json['unlocksCount']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ingredientId': serializer.toJson<int>(ingredientId),
      'unlocksCount': serializer.toJson<int>(unlocksCount),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  ShoppingListData copyWith({
    int? id,
    int? ingredientId,
    int? unlocksCount,
    DateTime? addedAt,
  }) => ShoppingListData(
    id: id ?? this.id,
    ingredientId: ingredientId ?? this.ingredientId,
    unlocksCount: unlocksCount ?? this.unlocksCount,
    addedAt: addedAt ?? this.addedAt,
  );
  ShoppingListData copyWithCompanion(ShoppingListCompanion data) {
    return ShoppingListData(
      id: data.id.present ? data.id.value : this.id,
      ingredientId: data.ingredientId.present
          ? data.ingredientId.value
          : this.ingredientId,
      unlocksCount: data.unlocksCount.present
          ? data.unlocksCount.value
          : this.unlocksCount,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShoppingListData(')
          ..write('id: $id, ')
          ..write('ingredientId: $ingredientId, ')
          ..write('unlocksCount: $unlocksCount, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, ingredientId, unlocksCount, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShoppingListData &&
          other.id == this.id &&
          other.ingredientId == this.ingredientId &&
          other.unlocksCount == this.unlocksCount &&
          other.addedAt == this.addedAt);
}

class ShoppingListCompanion extends UpdateCompanion<ShoppingListData> {
  final Value<int> id;
  final Value<int> ingredientId;
  final Value<int> unlocksCount;
  final Value<DateTime> addedAt;
  const ShoppingListCompanion({
    this.id = const Value.absent(),
    this.ingredientId = const Value.absent(),
    this.unlocksCount = const Value.absent(),
    this.addedAt = const Value.absent(),
  });
  ShoppingListCompanion.insert({
    this.id = const Value.absent(),
    required int ingredientId,
    this.unlocksCount = const Value.absent(),
    this.addedAt = const Value.absent(),
  }) : ingredientId = Value(ingredientId);
  static Insertable<ShoppingListData> custom({
    Expression<int>? id,
    Expression<int>? ingredientId,
    Expression<int>? unlocksCount,
    Expression<DateTime>? addedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ingredientId != null) 'ingredient_id': ingredientId,
      if (unlocksCount != null) 'unlocks_count': unlocksCount,
      if (addedAt != null) 'added_at': addedAt,
    });
  }

  ShoppingListCompanion copyWith({
    Value<int>? id,
    Value<int>? ingredientId,
    Value<int>? unlocksCount,
    Value<DateTime>? addedAt,
  }) {
    return ShoppingListCompanion(
      id: id ?? this.id,
      ingredientId: ingredientId ?? this.ingredientId,
      unlocksCount: unlocksCount ?? this.unlocksCount,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ingredientId.present) {
      map['ingredient_id'] = Variable<int>(ingredientId.value);
    }
    if (unlocksCount.present) {
      map['unlocks_count'] = Variable<int>(unlocksCount.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShoppingListCompanion(')
          ..write('id: $id, ')
          ..write('ingredientId: $ingredientId, ')
          ..write('unlocksCount: $unlocksCount, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CocktailsTable cocktails = $CocktailsTable(this);
  late final $IngredientsTable ingredients = $IngredientsTable(this);
  late final $CocktailIngredientsTable cocktailIngredients =
      $CocktailIngredientsTable(this);
  late final $CollectionsTable collections = $CollectionsTable(this);
  late final $CollectionCocktailsTable collectionCocktails =
      $CollectionCocktailsTable(this);
  late final $SavedBarsTable savedBars = $SavedBarsTable(this);
  late final $SavedBarIngredientsTable savedBarIngredients =
      $SavedBarIngredientsTable(this);
  late final $ShoppingListTable shoppingList = $ShoppingListTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cocktails,
    ingredients,
    cocktailIngredients,
    collections,
    collectionCocktails,
    savedBars,
    savedBarIngredients,
    shoppingList,
  ];
}

typedef $$CocktailsTableCreateCompanionBuilder =
    CocktailsCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> description,
      required String method,
      Value<String?> methodInstructions,
      Value<String?> history,
      required String glass,
      Value<String?> ice,
      Value<String?> garnish,
      required String baseSpirit,
      required int difficulty,
      Value<String?> tags,
      Value<String?> imagePath,
    });
typedef $$CocktailsTableUpdateCompanionBuilder =
    CocktailsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> description,
      Value<String> method,
      Value<String?> methodInstructions,
      Value<String?> history,
      Value<String> glass,
      Value<String?> ice,
      Value<String?> garnish,
      Value<String> baseSpirit,
      Value<int> difficulty,
      Value<String?> tags,
      Value<String?> imagePath,
    });

final class $$CocktailsTableReferences
    extends BaseReferences<_$AppDatabase, $CocktailsTable, Cocktail> {
  $$CocktailsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<
    $CocktailIngredientsTable,
    List<CocktailIngredient>
  >
  _cocktailIngredientsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.cocktailIngredients,
        aliasName: $_aliasNameGenerator(
          db.cocktails.id,
          db.cocktailIngredients.cocktailId,
        ),
      );

  $$CocktailIngredientsTableProcessedTableManager get cocktailIngredientsRefs {
    final manager = $$CocktailIngredientsTableTableManager(
      $_db,
      $_db.cocktailIngredients,
    ).filter((f) => f.cocktailId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _cocktailIngredientsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $CollectionCocktailsTable,
    List<CollectionCocktail>
  >
  _collectionCocktailsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.collectionCocktails,
        aliasName: $_aliasNameGenerator(
          db.cocktails.id,
          db.collectionCocktails.cocktailId,
        ),
      );

  $$CollectionCocktailsTableProcessedTableManager get collectionCocktailsRefs {
    final manager = $$CollectionCocktailsTableTableManager(
      $_db,
      $_db.collectionCocktails,
    ).filter((f) => f.cocktailId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _collectionCocktailsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CocktailsTableFilterComposer
    extends Composer<_$AppDatabase, $CocktailsTable> {
  $$CocktailsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get methodInstructions => $composableBuilder(
    column: $table.methodInstructions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get history => $composableBuilder(
    column: $table.history,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get glass => $composableBuilder(
    column: $table.glass,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ice => $composableBuilder(
    column: $table.ice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get garnish => $composableBuilder(
    column: $table.garnish,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseSpirit => $composableBuilder(
    column: $table.baseSpirit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> cocktailIngredientsRefs(
    Expression<bool> Function($$CocktailIngredientsTableFilterComposer f) f,
  ) {
    final $$CocktailIngredientsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cocktailIngredients,
      getReferencedColumn: (t) => t.cocktailId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CocktailIngredientsTableFilterComposer(
            $db: $db,
            $table: $db.cocktailIngredients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> collectionCocktailsRefs(
    Expression<bool> Function($$CollectionCocktailsTableFilterComposer f) f,
  ) {
    final $$CollectionCocktailsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.collectionCocktails,
      getReferencedColumn: (t) => t.cocktailId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CollectionCocktailsTableFilterComposer(
            $db: $db,
            $table: $db.collectionCocktails,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CocktailsTableOrderingComposer
    extends Composer<_$AppDatabase, $CocktailsTable> {
  $$CocktailsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get methodInstructions => $composableBuilder(
    column: $table.methodInstructions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get history => $composableBuilder(
    column: $table.history,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get glass => $composableBuilder(
    column: $table.glass,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ice => $composableBuilder(
    column: $table.ice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get garnish => $composableBuilder(
    column: $table.garnish,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseSpirit => $composableBuilder(
    column: $table.baseSpirit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CocktailsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CocktailsTable> {
  $$CocktailsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);

  GeneratedColumn<String> get methodInstructions => $composableBuilder(
    column: $table.methodInstructions,
    builder: (column) => column,
  );

  GeneratedColumn<String> get history =>
      $composableBuilder(column: $table.history, builder: (column) => column);

  GeneratedColumn<String> get glass =>
      $composableBuilder(column: $table.glass, builder: (column) => column);

  GeneratedColumn<String> get ice =>
      $composableBuilder(column: $table.ice, builder: (column) => column);

  GeneratedColumn<String> get garnish =>
      $composableBuilder(column: $table.garnish, builder: (column) => column);

  GeneratedColumn<String> get baseSpirit => $composableBuilder(
    column: $table.baseSpirit,
    builder: (column) => column,
  );

  GeneratedColumn<int> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  Expression<T> cocktailIngredientsRefs<T extends Object>(
    Expression<T> Function($$CocktailIngredientsTableAnnotationComposer a) f,
  ) {
    final $$CocktailIngredientsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.cocktailIngredients,
          getReferencedColumn: (t) => t.cocktailId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CocktailIngredientsTableAnnotationComposer(
                $db: $db,
                $table: $db.cocktailIngredients,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> collectionCocktailsRefs<T extends Object>(
    Expression<T> Function($$CollectionCocktailsTableAnnotationComposer a) f,
  ) {
    final $$CollectionCocktailsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.collectionCocktails,
          getReferencedColumn: (t) => t.cocktailId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CollectionCocktailsTableAnnotationComposer(
                $db: $db,
                $table: $db.collectionCocktails,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$CocktailsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CocktailsTable,
          Cocktail,
          $$CocktailsTableFilterComposer,
          $$CocktailsTableOrderingComposer,
          $$CocktailsTableAnnotationComposer,
          $$CocktailsTableCreateCompanionBuilder,
          $$CocktailsTableUpdateCompanionBuilder,
          (Cocktail, $$CocktailsTableReferences),
          Cocktail,
          PrefetchHooks Function({
            bool cocktailIngredientsRefs,
            bool collectionCocktailsRefs,
          })
        > {
  $$CocktailsTableTableManager(_$AppDatabase db, $CocktailsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CocktailsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CocktailsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CocktailsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String> method = const Value.absent(),
                Value<String?> methodInstructions = const Value.absent(),
                Value<String?> history = const Value.absent(),
                Value<String> glass = const Value.absent(),
                Value<String?> ice = const Value.absent(),
                Value<String?> garnish = const Value.absent(),
                Value<String> baseSpirit = const Value.absent(),
                Value<int> difficulty = const Value.absent(),
                Value<String?> tags = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
              }) => CocktailsCompanion(
                id: id,
                name: name,
                description: description,
                method: method,
                methodInstructions: methodInstructions,
                history: history,
                glass: glass,
                ice: ice,
                garnish: garnish,
                baseSpirit: baseSpirit,
                difficulty: difficulty,
                tags: tags,
                imagePath: imagePath,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> description = const Value.absent(),
                required String method,
                Value<String?> methodInstructions = const Value.absent(),
                Value<String?> history = const Value.absent(),
                required String glass,
                Value<String?> ice = const Value.absent(),
                Value<String?> garnish = const Value.absent(),
                required String baseSpirit,
                required int difficulty,
                Value<String?> tags = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
              }) => CocktailsCompanion.insert(
                id: id,
                name: name,
                description: description,
                method: method,
                methodInstructions: methodInstructions,
                history: history,
                glass: glass,
                ice: ice,
                garnish: garnish,
                baseSpirit: baseSpirit,
                difficulty: difficulty,
                tags: tags,
                imagePath: imagePath,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CocktailsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                cocktailIngredientsRefs = false,
                collectionCocktailsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (cocktailIngredientsRefs) db.cocktailIngredients,
                    if (collectionCocktailsRefs) db.collectionCocktails,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (cocktailIngredientsRefs)
                        await $_getPrefetchedData<
                          Cocktail,
                          $CocktailsTable,
                          CocktailIngredient
                        >(
                          currentTable: table,
                          referencedTable: $$CocktailsTableReferences
                              ._cocktailIngredientsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CocktailsTableReferences(
                                db,
                                table,
                                p0,
                              ).cocktailIngredientsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.cocktailId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (collectionCocktailsRefs)
                        await $_getPrefetchedData<
                          Cocktail,
                          $CocktailsTable,
                          CollectionCocktail
                        >(
                          currentTable: table,
                          referencedTable: $$CocktailsTableReferences
                              ._collectionCocktailsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CocktailsTableReferences(
                                db,
                                table,
                                p0,
                              ).collectionCocktailsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.cocktailId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CocktailsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CocktailsTable,
      Cocktail,
      $$CocktailsTableFilterComposer,
      $$CocktailsTableOrderingComposer,
      $$CocktailsTableAnnotationComposer,
      $$CocktailsTableCreateCompanionBuilder,
      $$CocktailsTableUpdateCompanionBuilder,
      (Cocktail, $$CocktailsTableReferences),
      Cocktail,
      PrefetchHooks Function({
        bool cocktailIngredientsRefs,
        bool collectionCocktailsRefs,
      })
    >;
typedef $$IngredientsTableCreateCompanionBuilder =
    IngredientsCompanion Function({
      Value<int> id,
      required String name,
      Value<String> category,
    });
typedef $$IngredientsTableUpdateCompanionBuilder =
    IngredientsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> category,
    });

final class $$IngredientsTableReferences
    extends BaseReferences<_$AppDatabase, $IngredientsTable, Ingredient> {
  $$IngredientsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<
    $CocktailIngredientsTable,
    List<CocktailIngredient>
  >
  _cocktailIngredientsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.cocktailIngredients,
        aliasName: $_aliasNameGenerator(
          db.ingredients.id,
          db.cocktailIngredients.ingredientId,
        ),
      );

  $$CocktailIngredientsTableProcessedTableManager get cocktailIngredientsRefs {
    final manager = $$CocktailIngredientsTableTableManager(
      $_db,
      $_db.cocktailIngredients,
    ).filter((f) => f.ingredientId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _cocktailIngredientsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $SavedBarIngredientsTable,
    List<SavedBarIngredient>
  >
  _savedBarIngredientsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.savedBarIngredients,
        aliasName: $_aliasNameGenerator(
          db.ingredients.id,
          db.savedBarIngredients.ingredientId,
        ),
      );

  $$SavedBarIngredientsTableProcessedTableManager get savedBarIngredientsRefs {
    final manager = $$SavedBarIngredientsTableTableManager(
      $_db,
      $_db.savedBarIngredients,
    ).filter((f) => f.ingredientId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _savedBarIngredientsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ShoppingListTable, List<ShoppingListData>>
  _shoppingListRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.shoppingList,
    aliasName: $_aliasNameGenerator(
      db.ingredients.id,
      db.shoppingList.ingredientId,
    ),
  );

  $$ShoppingListTableProcessedTableManager get shoppingListRefs {
    final manager = $$ShoppingListTableTableManager(
      $_db,
      $_db.shoppingList,
    ).filter((f) => f.ingredientId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_shoppingListRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$IngredientsTableFilterComposer
    extends Composer<_$AppDatabase, $IngredientsTable> {
  $$IngredientsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> cocktailIngredientsRefs(
    Expression<bool> Function($$CocktailIngredientsTableFilterComposer f) f,
  ) {
    final $$CocktailIngredientsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cocktailIngredients,
      getReferencedColumn: (t) => t.ingredientId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CocktailIngredientsTableFilterComposer(
            $db: $db,
            $table: $db.cocktailIngredients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> savedBarIngredientsRefs(
    Expression<bool> Function($$SavedBarIngredientsTableFilterComposer f) f,
  ) {
    final $$SavedBarIngredientsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.savedBarIngredients,
      getReferencedColumn: (t) => t.ingredientId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedBarIngredientsTableFilterComposer(
            $db: $db,
            $table: $db.savedBarIngredients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> shoppingListRefs(
    Expression<bool> Function($$ShoppingListTableFilterComposer f) f,
  ) {
    final $$ShoppingListTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shoppingList,
      getReferencedColumn: (t) => t.ingredientId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShoppingListTableFilterComposer(
            $db: $db,
            $table: $db.shoppingList,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$IngredientsTableOrderingComposer
    extends Composer<_$AppDatabase, $IngredientsTable> {
  $$IngredientsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$IngredientsTableAnnotationComposer
    extends Composer<_$AppDatabase, $IngredientsTable> {
  $$IngredientsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  Expression<T> cocktailIngredientsRefs<T extends Object>(
    Expression<T> Function($$CocktailIngredientsTableAnnotationComposer a) f,
  ) {
    final $$CocktailIngredientsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.cocktailIngredients,
          getReferencedColumn: (t) => t.ingredientId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CocktailIngredientsTableAnnotationComposer(
                $db: $db,
                $table: $db.cocktailIngredients,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> savedBarIngredientsRefs<T extends Object>(
    Expression<T> Function($$SavedBarIngredientsTableAnnotationComposer a) f,
  ) {
    final $$SavedBarIngredientsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.savedBarIngredients,
          getReferencedColumn: (t) => t.ingredientId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$SavedBarIngredientsTableAnnotationComposer(
                $db: $db,
                $table: $db.savedBarIngredients,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> shoppingListRefs<T extends Object>(
    Expression<T> Function($$ShoppingListTableAnnotationComposer a) f,
  ) {
    final $$ShoppingListTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shoppingList,
      getReferencedColumn: (t) => t.ingredientId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShoppingListTableAnnotationComposer(
            $db: $db,
            $table: $db.shoppingList,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$IngredientsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $IngredientsTable,
          Ingredient,
          $$IngredientsTableFilterComposer,
          $$IngredientsTableOrderingComposer,
          $$IngredientsTableAnnotationComposer,
          $$IngredientsTableCreateCompanionBuilder,
          $$IngredientsTableUpdateCompanionBuilder,
          (Ingredient, $$IngredientsTableReferences),
          Ingredient,
          PrefetchHooks Function({
            bool cocktailIngredientsRefs,
            bool savedBarIngredientsRefs,
            bool shoppingListRefs,
          })
        > {
  $$IngredientsTableTableManager(_$AppDatabase db, $IngredientsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IngredientsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IngredientsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IngredientsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> category = const Value.absent(),
              }) =>
                  IngredientsCompanion(id: id, name: name, category: category),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String> category = const Value.absent(),
              }) => IngredientsCompanion.insert(
                id: id,
                name: name,
                category: category,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$IngredientsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                cocktailIngredientsRefs = false,
                savedBarIngredientsRefs = false,
                shoppingListRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (cocktailIngredientsRefs) db.cocktailIngredients,
                    if (savedBarIngredientsRefs) db.savedBarIngredients,
                    if (shoppingListRefs) db.shoppingList,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (cocktailIngredientsRefs)
                        await $_getPrefetchedData<
                          Ingredient,
                          $IngredientsTable,
                          CocktailIngredient
                        >(
                          currentTable: table,
                          referencedTable: $$IngredientsTableReferences
                              ._cocktailIngredientsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$IngredientsTableReferences(
                                db,
                                table,
                                p0,
                              ).cocktailIngredientsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.ingredientId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (savedBarIngredientsRefs)
                        await $_getPrefetchedData<
                          Ingredient,
                          $IngredientsTable,
                          SavedBarIngredient
                        >(
                          currentTable: table,
                          referencedTable: $$IngredientsTableReferences
                              ._savedBarIngredientsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$IngredientsTableReferences(
                                db,
                                table,
                                p0,
                              ).savedBarIngredientsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.ingredientId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (shoppingListRefs)
                        await $_getPrefetchedData<
                          Ingredient,
                          $IngredientsTable,
                          ShoppingListData
                        >(
                          currentTable: table,
                          referencedTable: $$IngredientsTableReferences
                              ._shoppingListRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$IngredientsTableReferences(
                                db,
                                table,
                                p0,
                              ).shoppingListRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.ingredientId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$IngredientsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $IngredientsTable,
      Ingredient,
      $$IngredientsTableFilterComposer,
      $$IngredientsTableOrderingComposer,
      $$IngredientsTableAnnotationComposer,
      $$IngredientsTableCreateCompanionBuilder,
      $$IngredientsTableUpdateCompanionBuilder,
      (Ingredient, $$IngredientsTableReferences),
      Ingredient,
      PrefetchHooks Function({
        bool cocktailIngredientsRefs,
        bool savedBarIngredientsRefs,
        bool shoppingListRefs,
      })
    >;
typedef $$CocktailIngredientsTableCreateCompanionBuilder =
    CocktailIngredientsCompanion Function({
      Value<int> id,
      required int cocktailId,
      required int ingredientId,
      required double amount,
      required String unit,
      Value<String?> prepNote,
    });
typedef $$CocktailIngredientsTableUpdateCompanionBuilder =
    CocktailIngredientsCompanion Function({
      Value<int> id,
      Value<int> cocktailId,
      Value<int> ingredientId,
      Value<double> amount,
      Value<String> unit,
      Value<String?> prepNote,
    });

final class $$CocktailIngredientsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $CocktailIngredientsTable,
          CocktailIngredient
        > {
  $$CocktailIngredientsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CocktailsTable _cocktailIdTable(_$AppDatabase db) =>
      db.cocktails.createAlias(
        $_aliasNameGenerator(
          db.cocktailIngredients.cocktailId,
          db.cocktails.id,
        ),
      );

  $$CocktailsTableProcessedTableManager get cocktailId {
    final $_column = $_itemColumn<int>('cocktail_id')!;

    final manager = $$CocktailsTableTableManager(
      $_db,
      $_db.cocktails,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cocktailIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $IngredientsTable _ingredientIdTable(_$AppDatabase db) =>
      db.ingredients.createAlias(
        $_aliasNameGenerator(
          db.cocktailIngredients.ingredientId,
          db.ingredients.id,
        ),
      );

  $$IngredientsTableProcessedTableManager get ingredientId {
    final $_column = $_itemColumn<int>('ingredient_id')!;

    final manager = $$IngredientsTableTableManager(
      $_db,
      $_db.ingredients,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_ingredientIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CocktailIngredientsTableFilterComposer
    extends Composer<_$AppDatabase, $CocktailIngredientsTable> {
  $$CocktailIngredientsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prepNote => $composableBuilder(
    column: $table.prepNote,
    builder: (column) => ColumnFilters(column),
  );

  $$CocktailsTableFilterComposer get cocktailId {
    final $$CocktailsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cocktailId,
      referencedTable: $db.cocktails,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CocktailsTableFilterComposer(
            $db: $db,
            $table: $db.cocktails,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$IngredientsTableFilterComposer get ingredientId {
    final $$IngredientsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ingredientId,
      referencedTable: $db.ingredients,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IngredientsTableFilterComposer(
            $db: $db,
            $table: $db.ingredients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CocktailIngredientsTableOrderingComposer
    extends Composer<_$AppDatabase, $CocktailIngredientsTable> {
  $$CocktailIngredientsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prepNote => $composableBuilder(
    column: $table.prepNote,
    builder: (column) => ColumnOrderings(column),
  );

  $$CocktailsTableOrderingComposer get cocktailId {
    final $$CocktailsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cocktailId,
      referencedTable: $db.cocktails,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CocktailsTableOrderingComposer(
            $db: $db,
            $table: $db.cocktails,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$IngredientsTableOrderingComposer get ingredientId {
    final $$IngredientsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ingredientId,
      referencedTable: $db.ingredients,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IngredientsTableOrderingComposer(
            $db: $db,
            $table: $db.ingredients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CocktailIngredientsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CocktailIngredientsTable> {
  $$CocktailIngredientsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<String> get prepNote =>
      $composableBuilder(column: $table.prepNote, builder: (column) => column);

  $$CocktailsTableAnnotationComposer get cocktailId {
    final $$CocktailsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cocktailId,
      referencedTable: $db.cocktails,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CocktailsTableAnnotationComposer(
            $db: $db,
            $table: $db.cocktails,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$IngredientsTableAnnotationComposer get ingredientId {
    final $$IngredientsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ingredientId,
      referencedTable: $db.ingredients,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IngredientsTableAnnotationComposer(
            $db: $db,
            $table: $db.ingredients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CocktailIngredientsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CocktailIngredientsTable,
          CocktailIngredient,
          $$CocktailIngredientsTableFilterComposer,
          $$CocktailIngredientsTableOrderingComposer,
          $$CocktailIngredientsTableAnnotationComposer,
          $$CocktailIngredientsTableCreateCompanionBuilder,
          $$CocktailIngredientsTableUpdateCompanionBuilder,
          (CocktailIngredient, $$CocktailIngredientsTableReferences),
          CocktailIngredient,
          PrefetchHooks Function({bool cocktailId, bool ingredientId})
        > {
  $$CocktailIngredientsTableTableManager(
    _$AppDatabase db,
    $CocktailIngredientsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CocktailIngredientsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CocktailIngredientsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CocktailIngredientsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> cocktailId = const Value.absent(),
                Value<int> ingredientId = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<String?> prepNote = const Value.absent(),
              }) => CocktailIngredientsCompanion(
                id: id,
                cocktailId: cocktailId,
                ingredientId: ingredientId,
                amount: amount,
                unit: unit,
                prepNote: prepNote,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int cocktailId,
                required int ingredientId,
                required double amount,
                required String unit,
                Value<String?> prepNote = const Value.absent(),
              }) => CocktailIngredientsCompanion.insert(
                id: id,
                cocktailId: cocktailId,
                ingredientId: ingredientId,
                amount: amount,
                unit: unit,
                prepNote: prepNote,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CocktailIngredientsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cocktailId = false, ingredientId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (cocktailId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.cocktailId,
                                referencedTable:
                                    $$CocktailIngredientsTableReferences
                                        ._cocktailIdTable(db),
                                referencedColumn:
                                    $$CocktailIngredientsTableReferences
                                        ._cocktailIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (ingredientId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.ingredientId,
                                referencedTable:
                                    $$CocktailIngredientsTableReferences
                                        ._ingredientIdTable(db),
                                referencedColumn:
                                    $$CocktailIngredientsTableReferences
                                        ._ingredientIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CocktailIngredientsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CocktailIngredientsTable,
      CocktailIngredient,
      $$CocktailIngredientsTableFilterComposer,
      $$CocktailIngredientsTableOrderingComposer,
      $$CocktailIngredientsTableAnnotationComposer,
      $$CocktailIngredientsTableCreateCompanionBuilder,
      $$CocktailIngredientsTableUpdateCompanionBuilder,
      (CocktailIngredient, $$CocktailIngredientsTableReferences),
      CocktailIngredient,
      PrefetchHooks Function({bool cocktailId, bool ingredientId})
    >;
typedef $$CollectionsTableCreateCompanionBuilder =
    CollectionsCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> description,
      Value<DateTime> createdAt,
    });
typedef $$CollectionsTableUpdateCompanionBuilder =
    CollectionsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> description,
      Value<DateTime> createdAt,
    });

final class $$CollectionsTableReferences
    extends BaseReferences<_$AppDatabase, $CollectionsTable, Collection> {
  $$CollectionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<
    $CollectionCocktailsTable,
    List<CollectionCocktail>
  >
  _collectionCocktailsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.collectionCocktails,
        aliasName: $_aliasNameGenerator(
          db.collections.id,
          db.collectionCocktails.collectionId,
        ),
      );

  $$CollectionCocktailsTableProcessedTableManager get collectionCocktailsRefs {
    final manager = $$CollectionCocktailsTableTableManager(
      $_db,
      $_db.collectionCocktails,
    ).filter((f) => f.collectionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _collectionCocktailsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CollectionsTableFilterComposer
    extends Composer<_$AppDatabase, $CollectionsTable> {
  $$CollectionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> collectionCocktailsRefs(
    Expression<bool> Function($$CollectionCocktailsTableFilterComposer f) f,
  ) {
    final $$CollectionCocktailsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.collectionCocktails,
      getReferencedColumn: (t) => t.collectionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CollectionCocktailsTableFilterComposer(
            $db: $db,
            $table: $db.collectionCocktails,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CollectionsTableOrderingComposer
    extends Composer<_$AppDatabase, $CollectionsTable> {
  $$CollectionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CollectionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CollectionsTable> {
  $$CollectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> collectionCocktailsRefs<T extends Object>(
    Expression<T> Function($$CollectionCocktailsTableAnnotationComposer a) f,
  ) {
    final $$CollectionCocktailsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.collectionCocktails,
          getReferencedColumn: (t) => t.collectionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CollectionCocktailsTableAnnotationComposer(
                $db: $db,
                $table: $db.collectionCocktails,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$CollectionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CollectionsTable,
          Collection,
          $$CollectionsTableFilterComposer,
          $$CollectionsTableOrderingComposer,
          $$CollectionsTableAnnotationComposer,
          $$CollectionsTableCreateCompanionBuilder,
          $$CollectionsTableUpdateCompanionBuilder,
          (Collection, $$CollectionsTableReferences),
          Collection,
          PrefetchHooks Function({bool collectionCocktailsRefs})
        > {
  $$CollectionsTableTableManager(_$AppDatabase db, $CollectionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CollectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CollectionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CollectionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => CollectionsCompanion(
                id: id,
                name: name,
                description: description,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> description = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => CollectionsCompanion.insert(
                id: id,
                name: name,
                description: description,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CollectionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({collectionCocktailsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (collectionCocktailsRefs) db.collectionCocktails,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (collectionCocktailsRefs)
                    await $_getPrefetchedData<
                      Collection,
                      $CollectionsTable,
                      CollectionCocktail
                    >(
                      currentTable: table,
                      referencedTable: $$CollectionsTableReferences
                          ._collectionCocktailsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CollectionsTableReferences(
                            db,
                            table,
                            p0,
                          ).collectionCocktailsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.collectionId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CollectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CollectionsTable,
      Collection,
      $$CollectionsTableFilterComposer,
      $$CollectionsTableOrderingComposer,
      $$CollectionsTableAnnotationComposer,
      $$CollectionsTableCreateCompanionBuilder,
      $$CollectionsTableUpdateCompanionBuilder,
      (Collection, $$CollectionsTableReferences),
      Collection,
      PrefetchHooks Function({bool collectionCocktailsRefs})
    >;
typedef $$CollectionCocktailsTableCreateCompanionBuilder =
    CollectionCocktailsCompanion Function({
      Value<int> id,
      required int collectionId,
      required int cocktailId,
      Value<DateTime> addedAt,
    });
typedef $$CollectionCocktailsTableUpdateCompanionBuilder =
    CollectionCocktailsCompanion Function({
      Value<int> id,
      Value<int> collectionId,
      Value<int> cocktailId,
      Value<DateTime> addedAt,
    });

final class $$CollectionCocktailsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $CollectionCocktailsTable,
          CollectionCocktail
        > {
  $$CollectionCocktailsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CollectionsTable _collectionIdTable(_$AppDatabase db) =>
      db.collections.createAlias(
        $_aliasNameGenerator(
          db.collectionCocktails.collectionId,
          db.collections.id,
        ),
      );

  $$CollectionsTableProcessedTableManager get collectionId {
    final $_column = $_itemColumn<int>('collection_id')!;

    final manager = $$CollectionsTableTableManager(
      $_db,
      $_db.collections,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_collectionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CocktailsTable _cocktailIdTable(_$AppDatabase db) =>
      db.cocktails.createAlias(
        $_aliasNameGenerator(
          db.collectionCocktails.cocktailId,
          db.cocktails.id,
        ),
      );

  $$CocktailsTableProcessedTableManager get cocktailId {
    final $_column = $_itemColumn<int>('cocktail_id')!;

    final manager = $$CocktailsTableTableManager(
      $_db,
      $_db.cocktails,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cocktailIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CollectionCocktailsTableFilterComposer
    extends Composer<_$AppDatabase, $CollectionCocktailsTable> {
  $$CollectionCocktailsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CollectionsTableFilterComposer get collectionId {
    final $$CollectionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.collectionId,
      referencedTable: $db.collections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CollectionsTableFilterComposer(
            $db: $db,
            $table: $db.collections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CocktailsTableFilterComposer get cocktailId {
    final $$CocktailsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cocktailId,
      referencedTable: $db.cocktails,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CocktailsTableFilterComposer(
            $db: $db,
            $table: $db.cocktails,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CollectionCocktailsTableOrderingComposer
    extends Composer<_$AppDatabase, $CollectionCocktailsTable> {
  $$CollectionCocktailsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CollectionsTableOrderingComposer get collectionId {
    final $$CollectionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.collectionId,
      referencedTable: $db.collections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CollectionsTableOrderingComposer(
            $db: $db,
            $table: $db.collections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CocktailsTableOrderingComposer get cocktailId {
    final $$CocktailsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cocktailId,
      referencedTable: $db.cocktails,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CocktailsTableOrderingComposer(
            $db: $db,
            $table: $db.cocktails,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CollectionCocktailsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CollectionCocktailsTable> {
  $$CollectionCocktailsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$CollectionsTableAnnotationComposer get collectionId {
    final $$CollectionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.collectionId,
      referencedTable: $db.collections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CollectionsTableAnnotationComposer(
            $db: $db,
            $table: $db.collections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CocktailsTableAnnotationComposer get cocktailId {
    final $$CocktailsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cocktailId,
      referencedTable: $db.cocktails,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CocktailsTableAnnotationComposer(
            $db: $db,
            $table: $db.cocktails,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CollectionCocktailsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CollectionCocktailsTable,
          CollectionCocktail,
          $$CollectionCocktailsTableFilterComposer,
          $$CollectionCocktailsTableOrderingComposer,
          $$CollectionCocktailsTableAnnotationComposer,
          $$CollectionCocktailsTableCreateCompanionBuilder,
          $$CollectionCocktailsTableUpdateCompanionBuilder,
          (CollectionCocktail, $$CollectionCocktailsTableReferences),
          CollectionCocktail,
          PrefetchHooks Function({bool collectionId, bool cocktailId})
        > {
  $$CollectionCocktailsTableTableManager(
    _$AppDatabase db,
    $CollectionCocktailsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CollectionCocktailsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CollectionCocktailsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CollectionCocktailsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> collectionId = const Value.absent(),
                Value<int> cocktailId = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
              }) => CollectionCocktailsCompanion(
                id: id,
                collectionId: collectionId,
                cocktailId: cocktailId,
                addedAt: addedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int collectionId,
                required int cocktailId,
                Value<DateTime> addedAt = const Value.absent(),
              }) => CollectionCocktailsCompanion.insert(
                id: id,
                collectionId: collectionId,
                cocktailId: cocktailId,
                addedAt: addedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CollectionCocktailsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({collectionId = false, cocktailId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (collectionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.collectionId,
                                referencedTable:
                                    $$CollectionCocktailsTableReferences
                                        ._collectionIdTable(db),
                                referencedColumn:
                                    $$CollectionCocktailsTableReferences
                                        ._collectionIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (cocktailId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.cocktailId,
                                referencedTable:
                                    $$CollectionCocktailsTableReferences
                                        ._cocktailIdTable(db),
                                referencedColumn:
                                    $$CollectionCocktailsTableReferences
                                        ._cocktailIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CollectionCocktailsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CollectionCocktailsTable,
      CollectionCocktail,
      $$CollectionCocktailsTableFilterComposer,
      $$CollectionCocktailsTableOrderingComposer,
      $$CollectionCocktailsTableAnnotationComposer,
      $$CollectionCocktailsTableCreateCompanionBuilder,
      $$CollectionCocktailsTableUpdateCompanionBuilder,
      (CollectionCocktail, $$CollectionCocktailsTableReferences),
      CollectionCocktail,
      PrefetchHooks Function({bool collectionId, bool cocktailId})
    >;
typedef $$SavedBarsTableCreateCompanionBuilder =
    SavedBarsCompanion Function({
      Value<int> id,
      required String name,
      Value<bool> isDefault,
      Value<DateTime> createdAt,
      Value<DateTime> lastUsed,
    });
typedef $$SavedBarsTableUpdateCompanionBuilder =
    SavedBarsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<bool> isDefault,
      Value<DateTime> createdAt,
      Value<DateTime> lastUsed,
    });

final class $$SavedBarsTableReferences
    extends BaseReferences<_$AppDatabase, $SavedBarsTable, SavedBar> {
  $$SavedBarsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<
    $SavedBarIngredientsTable,
    List<SavedBarIngredient>
  >
  _savedBarIngredientsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.savedBarIngredients,
        aliasName: $_aliasNameGenerator(
          db.savedBars.id,
          db.savedBarIngredients.savedBarId,
        ),
      );

  $$SavedBarIngredientsTableProcessedTableManager get savedBarIngredientsRefs {
    final manager = $$SavedBarIngredientsTableTableManager(
      $_db,
      $_db.savedBarIngredients,
    ).filter((f) => f.savedBarId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _savedBarIngredientsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SavedBarsTableFilterComposer
    extends Composer<_$AppDatabase, $SavedBarsTable> {
  $$SavedBarsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUsed => $composableBuilder(
    column: $table.lastUsed,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> savedBarIngredientsRefs(
    Expression<bool> Function($$SavedBarIngredientsTableFilterComposer f) f,
  ) {
    final $$SavedBarIngredientsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.savedBarIngredients,
      getReferencedColumn: (t) => t.savedBarId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedBarIngredientsTableFilterComposer(
            $db: $db,
            $table: $db.savedBarIngredients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SavedBarsTableOrderingComposer
    extends Composer<_$AppDatabase, $SavedBarsTable> {
  $$SavedBarsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUsed => $composableBuilder(
    column: $table.lastUsed,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SavedBarsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SavedBarsTable> {
  $$SavedBarsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUsed =>
      $composableBuilder(column: $table.lastUsed, builder: (column) => column);

  Expression<T> savedBarIngredientsRefs<T extends Object>(
    Expression<T> Function($$SavedBarIngredientsTableAnnotationComposer a) f,
  ) {
    final $$SavedBarIngredientsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.savedBarIngredients,
          getReferencedColumn: (t) => t.savedBarId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$SavedBarIngredientsTableAnnotationComposer(
                $db: $db,
                $table: $db.savedBarIngredients,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$SavedBarsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SavedBarsTable,
          SavedBar,
          $$SavedBarsTableFilterComposer,
          $$SavedBarsTableOrderingComposer,
          $$SavedBarsTableAnnotationComposer,
          $$SavedBarsTableCreateCompanionBuilder,
          $$SavedBarsTableUpdateCompanionBuilder,
          (SavedBar, $$SavedBarsTableReferences),
          SavedBar,
          PrefetchHooks Function({bool savedBarIngredientsRefs})
        > {
  $$SavedBarsTableTableManager(_$AppDatabase db, $SavedBarsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedBarsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedBarsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavedBarsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> lastUsed = const Value.absent(),
              }) => SavedBarsCompanion(
                id: id,
                name: name,
                isDefault: isDefault,
                createdAt: createdAt,
                lastUsed: lastUsed,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<bool> isDefault = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> lastUsed = const Value.absent(),
              }) => SavedBarsCompanion.insert(
                id: id,
                name: name,
                isDefault: isDefault,
                createdAt: createdAt,
                lastUsed: lastUsed,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SavedBarsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({savedBarIngredientsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (savedBarIngredientsRefs) db.savedBarIngredients,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (savedBarIngredientsRefs)
                    await $_getPrefetchedData<
                      SavedBar,
                      $SavedBarsTable,
                      SavedBarIngredient
                    >(
                      currentTable: table,
                      referencedTable: $$SavedBarsTableReferences
                          ._savedBarIngredientsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$SavedBarsTableReferences(
                            db,
                            table,
                            p0,
                          ).savedBarIngredientsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.savedBarId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SavedBarsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SavedBarsTable,
      SavedBar,
      $$SavedBarsTableFilterComposer,
      $$SavedBarsTableOrderingComposer,
      $$SavedBarsTableAnnotationComposer,
      $$SavedBarsTableCreateCompanionBuilder,
      $$SavedBarsTableUpdateCompanionBuilder,
      (SavedBar, $$SavedBarsTableReferences),
      SavedBar,
      PrefetchHooks Function({bool savedBarIngredientsRefs})
    >;
typedef $$SavedBarIngredientsTableCreateCompanionBuilder =
    SavedBarIngredientsCompanion Function({
      Value<int> id,
      required int savedBarId,
      required int ingredientId,
      Value<DateTime> addedAt,
    });
typedef $$SavedBarIngredientsTableUpdateCompanionBuilder =
    SavedBarIngredientsCompanion Function({
      Value<int> id,
      Value<int> savedBarId,
      Value<int> ingredientId,
      Value<DateTime> addedAt,
    });

final class $$SavedBarIngredientsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $SavedBarIngredientsTable,
          SavedBarIngredient
        > {
  $$SavedBarIngredientsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SavedBarsTable _savedBarIdTable(_$AppDatabase db) =>
      db.savedBars.createAlias(
        $_aliasNameGenerator(
          db.savedBarIngredients.savedBarId,
          db.savedBars.id,
        ),
      );

  $$SavedBarsTableProcessedTableManager get savedBarId {
    final $_column = $_itemColumn<int>('saved_bar_id')!;

    final manager = $$SavedBarsTableTableManager(
      $_db,
      $_db.savedBars,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_savedBarIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $IngredientsTable _ingredientIdTable(_$AppDatabase db) =>
      db.ingredients.createAlias(
        $_aliasNameGenerator(
          db.savedBarIngredients.ingredientId,
          db.ingredients.id,
        ),
      );

  $$IngredientsTableProcessedTableManager get ingredientId {
    final $_column = $_itemColumn<int>('ingredient_id')!;

    final manager = $$IngredientsTableTableManager(
      $_db,
      $_db.ingredients,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_ingredientIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SavedBarIngredientsTableFilterComposer
    extends Composer<_$AppDatabase, $SavedBarIngredientsTable> {
  $$SavedBarIngredientsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SavedBarsTableFilterComposer get savedBarId {
    final $$SavedBarsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.savedBarId,
      referencedTable: $db.savedBars,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedBarsTableFilterComposer(
            $db: $db,
            $table: $db.savedBars,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$IngredientsTableFilterComposer get ingredientId {
    final $$IngredientsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ingredientId,
      referencedTable: $db.ingredients,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IngredientsTableFilterComposer(
            $db: $db,
            $table: $db.ingredients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SavedBarIngredientsTableOrderingComposer
    extends Composer<_$AppDatabase, $SavedBarIngredientsTable> {
  $$SavedBarIngredientsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SavedBarsTableOrderingComposer get savedBarId {
    final $$SavedBarsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.savedBarId,
      referencedTable: $db.savedBars,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedBarsTableOrderingComposer(
            $db: $db,
            $table: $db.savedBars,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$IngredientsTableOrderingComposer get ingredientId {
    final $$IngredientsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ingredientId,
      referencedTable: $db.ingredients,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IngredientsTableOrderingComposer(
            $db: $db,
            $table: $db.ingredients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SavedBarIngredientsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SavedBarIngredientsTable> {
  $$SavedBarIngredientsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$SavedBarsTableAnnotationComposer get savedBarId {
    final $$SavedBarsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.savedBarId,
      referencedTable: $db.savedBars,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedBarsTableAnnotationComposer(
            $db: $db,
            $table: $db.savedBars,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$IngredientsTableAnnotationComposer get ingredientId {
    final $$IngredientsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ingredientId,
      referencedTable: $db.ingredients,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IngredientsTableAnnotationComposer(
            $db: $db,
            $table: $db.ingredients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SavedBarIngredientsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SavedBarIngredientsTable,
          SavedBarIngredient,
          $$SavedBarIngredientsTableFilterComposer,
          $$SavedBarIngredientsTableOrderingComposer,
          $$SavedBarIngredientsTableAnnotationComposer,
          $$SavedBarIngredientsTableCreateCompanionBuilder,
          $$SavedBarIngredientsTableUpdateCompanionBuilder,
          (SavedBarIngredient, $$SavedBarIngredientsTableReferences),
          SavedBarIngredient,
          PrefetchHooks Function({bool savedBarId, bool ingredientId})
        > {
  $$SavedBarIngredientsTableTableManager(
    _$AppDatabase db,
    $SavedBarIngredientsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedBarIngredientsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedBarIngredientsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SavedBarIngredientsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> savedBarId = const Value.absent(),
                Value<int> ingredientId = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
              }) => SavedBarIngredientsCompanion(
                id: id,
                savedBarId: savedBarId,
                ingredientId: ingredientId,
                addedAt: addedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int savedBarId,
                required int ingredientId,
                Value<DateTime> addedAt = const Value.absent(),
              }) => SavedBarIngredientsCompanion.insert(
                id: id,
                savedBarId: savedBarId,
                ingredientId: ingredientId,
                addedAt: addedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SavedBarIngredientsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({savedBarId = false, ingredientId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (savedBarId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.savedBarId,
                                referencedTable:
                                    $$SavedBarIngredientsTableReferences
                                        ._savedBarIdTable(db),
                                referencedColumn:
                                    $$SavedBarIngredientsTableReferences
                                        ._savedBarIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (ingredientId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.ingredientId,
                                referencedTable:
                                    $$SavedBarIngredientsTableReferences
                                        ._ingredientIdTable(db),
                                referencedColumn:
                                    $$SavedBarIngredientsTableReferences
                                        ._ingredientIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SavedBarIngredientsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SavedBarIngredientsTable,
      SavedBarIngredient,
      $$SavedBarIngredientsTableFilterComposer,
      $$SavedBarIngredientsTableOrderingComposer,
      $$SavedBarIngredientsTableAnnotationComposer,
      $$SavedBarIngredientsTableCreateCompanionBuilder,
      $$SavedBarIngredientsTableUpdateCompanionBuilder,
      (SavedBarIngredient, $$SavedBarIngredientsTableReferences),
      SavedBarIngredient,
      PrefetchHooks Function({bool savedBarId, bool ingredientId})
    >;
typedef $$ShoppingListTableCreateCompanionBuilder =
    ShoppingListCompanion Function({
      Value<int> id,
      required int ingredientId,
      Value<int> unlocksCount,
      Value<DateTime> addedAt,
    });
typedef $$ShoppingListTableUpdateCompanionBuilder =
    ShoppingListCompanion Function({
      Value<int> id,
      Value<int> ingredientId,
      Value<int> unlocksCount,
      Value<DateTime> addedAt,
    });

final class $$ShoppingListTableReferences
    extends
        BaseReferences<_$AppDatabase, $ShoppingListTable, ShoppingListData> {
  $$ShoppingListTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $IngredientsTable _ingredientIdTable(_$AppDatabase db) =>
      db.ingredients.createAlias(
        $_aliasNameGenerator(db.shoppingList.ingredientId, db.ingredients.id),
      );

  $$IngredientsTableProcessedTableManager get ingredientId {
    final $_column = $_itemColumn<int>('ingredient_id')!;

    final manager = $$IngredientsTableTableManager(
      $_db,
      $_db.ingredients,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_ingredientIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ShoppingListTableFilterComposer
    extends Composer<_$AppDatabase, $ShoppingListTable> {
  $$ShoppingListTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unlocksCount => $composableBuilder(
    column: $table.unlocksCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$IngredientsTableFilterComposer get ingredientId {
    final $$IngredientsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ingredientId,
      referencedTable: $db.ingredients,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IngredientsTableFilterComposer(
            $db: $db,
            $table: $db.ingredients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShoppingListTableOrderingComposer
    extends Composer<_$AppDatabase, $ShoppingListTable> {
  $$ShoppingListTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unlocksCount => $composableBuilder(
    column: $table.unlocksCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$IngredientsTableOrderingComposer get ingredientId {
    final $$IngredientsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ingredientId,
      referencedTable: $db.ingredients,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IngredientsTableOrderingComposer(
            $db: $db,
            $table: $db.ingredients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShoppingListTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShoppingListTable> {
  $$ShoppingListTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get unlocksCount => $composableBuilder(
    column: $table.unlocksCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$IngredientsTableAnnotationComposer get ingredientId {
    final $$IngredientsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ingredientId,
      referencedTable: $db.ingredients,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IngredientsTableAnnotationComposer(
            $db: $db,
            $table: $db.ingredients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShoppingListTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ShoppingListTable,
          ShoppingListData,
          $$ShoppingListTableFilterComposer,
          $$ShoppingListTableOrderingComposer,
          $$ShoppingListTableAnnotationComposer,
          $$ShoppingListTableCreateCompanionBuilder,
          $$ShoppingListTableUpdateCompanionBuilder,
          (ShoppingListData, $$ShoppingListTableReferences),
          ShoppingListData,
          PrefetchHooks Function({bool ingredientId})
        > {
  $$ShoppingListTableTableManager(_$AppDatabase db, $ShoppingListTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShoppingListTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShoppingListTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShoppingListTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> ingredientId = const Value.absent(),
                Value<int> unlocksCount = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
              }) => ShoppingListCompanion(
                id: id,
                ingredientId: ingredientId,
                unlocksCount: unlocksCount,
                addedAt: addedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int ingredientId,
                Value<int> unlocksCount = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
              }) => ShoppingListCompanion.insert(
                id: id,
                ingredientId: ingredientId,
                unlocksCount: unlocksCount,
                addedAt: addedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ShoppingListTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({ingredientId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (ingredientId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.ingredientId,
                                referencedTable: $$ShoppingListTableReferences
                                    ._ingredientIdTable(db),
                                referencedColumn: $$ShoppingListTableReferences
                                    ._ingredientIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ShoppingListTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ShoppingListTable,
      ShoppingListData,
      $$ShoppingListTableFilterComposer,
      $$ShoppingListTableOrderingComposer,
      $$ShoppingListTableAnnotationComposer,
      $$ShoppingListTableCreateCompanionBuilder,
      $$ShoppingListTableUpdateCompanionBuilder,
      (ShoppingListData, $$ShoppingListTableReferences),
      ShoppingListData,
      PrefetchHooks Function({bool ingredientId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CocktailsTableTableManager get cocktails =>
      $$CocktailsTableTableManager(_db, _db.cocktails);
  $$IngredientsTableTableManager get ingredients =>
      $$IngredientsTableTableManager(_db, _db.ingredients);
  $$CocktailIngredientsTableTableManager get cocktailIngredients =>
      $$CocktailIngredientsTableTableManager(_db, _db.cocktailIngredients);
  $$CollectionsTableTableManager get collections =>
      $$CollectionsTableTableManager(_db, _db.collections);
  $$CollectionCocktailsTableTableManager get collectionCocktails =>
      $$CollectionCocktailsTableTableManager(_db, _db.collectionCocktails);
  $$SavedBarsTableTableManager get savedBars =>
      $$SavedBarsTableTableManager(_db, _db.savedBars);
  $$SavedBarIngredientsTableTableManager get savedBarIngredients =>
      $$SavedBarIngredientsTableTableManager(_db, _db.savedBarIngredients);
  $$ShoppingListTableTableManager get shoppingList =>
      $$ShoppingListTableTableManager(_db, _db.shoppingList);
}
