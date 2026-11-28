// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'listening_event_entity.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetListeningEventEntityCollection on Isar {
  IsarCollection<ListeningEventEntity> get listeningEventEntitys =>
      this.collection();
}

const ListeningEventEntitySchema = CollectionSchema(
  name: r'ListeningEventEntity',
  id: -8185046715747051609,
  properties: {
    r'album': PropertySchema(id: 0, name: r'album', type: IsarType.string),
    r'artist': PropertySchema(id: 1, name: r'artist', type: IsarType.string),
    r'completedRatio': PropertySchema(
      id: 2,
      name: r'completedRatio',
      type: IsarType.double,
    ),
    r'listenedMs': PropertySchema(
      id: 3,
      name: r'listenedMs',
      type: IsarType.long,
    ),
    r'playedAt': PropertySchema(
      id: 4,
      name: r'playedAt',
      type: IsarType.dateTime,
    ),
    r'sessionId': PropertySchema(
      id: 5,
      name: r'sessionId',
      type: IsarType.string,
    ),
    r'songId': PropertySchema(id: 6, name: r'songId', type: IsarType.long),
    r'title': PropertySchema(id: 7, name: r'title', type: IsarType.string),
  },

  estimateSize: _listeningEventEntityEstimateSize,
  serialize: _listeningEventEntitySerialize,
  deserialize: _listeningEventEntityDeserialize,
  deserializeProp: _listeningEventEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'songId': IndexSchema(
      id: -4588889454650216128,
      name: r'songId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'songId',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'sessionId': IndexSchema(
      id: 6949518585047923839,
      name: r'sessionId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'sessionId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'playedAt': IndexSchema(
      id: -3711549563919110219,
      name: r'playedAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'playedAt',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _listeningEventEntityGetId,
  getLinks: _listeningEventEntityGetLinks,
  attach: _listeningEventEntityAttach,
  version: '3.3.2',
);

int _listeningEventEntityEstimateSize(
  ListeningEventEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.album.length * 3;
  bytesCount += 3 + object.artist.length * 3;
  bytesCount += 3 + object.sessionId.length * 3;
  bytesCount += 3 + object.title.length * 3;
  return bytesCount;
}

void _listeningEventEntitySerialize(
  ListeningEventEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.album);
  writer.writeString(offsets[1], object.artist);
  writer.writeDouble(offsets[2], object.completedRatio);
  writer.writeLong(offsets[3], object.listenedMs);
  writer.writeDateTime(offsets[4], object.playedAt);
  writer.writeString(offsets[5], object.sessionId);
  writer.writeLong(offsets[6], object.songId);
  writer.writeString(offsets[7], object.title);
}

ListeningEventEntity _listeningEventEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ListeningEventEntity();
  object.album = reader.readString(offsets[0]);
  object.artist = reader.readString(offsets[1]);
  object.completedRatio = reader.readDouble(offsets[2]);
  object.id = id;
  object.listenedMs = reader.readLong(offsets[3]);
  object.playedAt = reader.readDateTime(offsets[4]);
  object.sessionId = reader.readString(offsets[5]);
  object.songId = reader.readLong(offsets[6]);
  object.title = reader.readString(offsets[7]);
  return object;
}

P _listeningEventEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readDouble(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readDateTime(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _listeningEventEntityGetId(ListeningEventEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _listeningEventEntityGetLinks(
  ListeningEventEntity object,
) {
  return [];
}

void _listeningEventEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  ListeningEventEntity object,
) {
  object.id = id;
}

extension ListeningEventEntityQueryWhereSort
    on QueryBuilder<ListeningEventEntity, ListeningEventEntity, QWhere> {
  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterWhere>
  anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterWhere>
  anySongId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'songId'),
      );
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterWhere>
  anyPlayedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'playedAt'),
      );
    });
  }
}

extension ListeningEventEntityQueryWhere
    on QueryBuilder<ListeningEventEntity, ListeningEventEntity, QWhereClause> {
  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterWhereClause>
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterWhereClause>
  idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterWhereClause>
  idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterWhereClause>
  songIdEqualTo(int songId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'songId', value: [songId]),
      );
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterWhereClause>
  songIdNotEqualTo(int songId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'songId',
                lower: [],
                upper: [songId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'songId',
                lower: [songId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'songId',
                lower: [songId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'songId',
                lower: [],
                upper: [songId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterWhereClause>
  songIdGreaterThan(int songId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'songId',
          lower: [songId],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterWhereClause>
  songIdLessThan(int songId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'songId',
          lower: [],
          upper: [songId],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterWhereClause>
  songIdBetween(
    int lowerSongId,
    int upperSongId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'songId',
          lower: [lowerSongId],
          includeLower: includeLower,
          upper: [upperSongId],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterWhereClause>
  sessionIdEqualTo(String sessionId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'sessionId', value: [sessionId]),
      );
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterWhereClause>
  sessionIdNotEqualTo(String sessionId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'sessionId',
                lower: [],
                upper: [sessionId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'sessionId',
                lower: [sessionId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'sessionId',
                lower: [sessionId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'sessionId',
                lower: [],
                upper: [sessionId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterWhereClause>
  playedAtEqualTo(DateTime playedAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'playedAt', value: [playedAt]),
      );
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterWhereClause>
  playedAtNotEqualTo(DateTime playedAt) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'playedAt',
                lower: [],
                upper: [playedAt],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'playedAt',
                lower: [playedAt],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'playedAt',
                lower: [playedAt],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'playedAt',
                lower: [],
                upper: [playedAt],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterWhereClause>
  playedAtGreaterThan(DateTime playedAt, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'playedAt',
          lower: [playedAt],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterWhereClause>
  playedAtLessThan(DateTime playedAt, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'playedAt',
          lower: [],
          upper: [playedAt],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterWhereClause>
  playedAtBetween(
    DateTime lowerPlayedAt,
    DateTime upperPlayedAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'playedAt',
          lower: [lowerPlayedAt],
          includeLower: includeLower,
          upper: [upperPlayedAt],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension ListeningEventEntityQueryFilter
    on
        QueryBuilder<
          ListeningEventEntity,
          ListeningEventEntity,
          QFilterCondition
        > {
  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  albumEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'album',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  albumGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'album',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  albumLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'album',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  albumBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'album',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  albumStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'album',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  albumEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'album',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  albumContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'album',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  albumMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'album',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  albumIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'album', value: ''),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  albumIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'album', value: ''),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  artistEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'artist',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  artistGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'artist',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  artistLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'artist',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  artistBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'artist',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  artistStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'artist',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  artistEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'artist',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  artistContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'artist',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  artistMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'artist',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  artistIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'artist', value: ''),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  artistIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'artist', value: ''),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  completedRatioEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'completedRatio',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  completedRatioGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'completedRatio',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  completedRatioLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'completedRatio',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  completedRatioBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'completedRatio',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  idLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  listenedMsEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'listenedMs', value: value),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  listenedMsGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'listenedMs',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  listenedMsLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'listenedMs',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  listenedMsBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'listenedMs',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  playedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'playedAt', value: value),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  playedAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'playedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  playedAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'playedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  playedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'playedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  sessionIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'sessionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  sessionIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sessionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  sessionIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sessionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  sessionIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sessionId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  sessionIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'sessionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  sessionIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'sessionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  sessionIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'sessionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  sessionIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'sessionId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  sessionIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'sessionId', value: ''),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  sessionIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'sessionId', value: ''),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  songIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'songId', value: value),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  songIdGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'songId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  songIdLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'songId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  songIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'songId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  titleEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  titleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  titleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  titleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'title',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  titleStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  titleEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  titleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  titleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'title',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'title', value: ''),
      );
    });
  }

  QueryBuilder<
    ListeningEventEntity,
    ListeningEventEntity,
    QAfterFilterCondition
  >
  titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'title', value: ''),
      );
    });
  }
}

extension ListeningEventEntityQueryObject
    on
        QueryBuilder<
          ListeningEventEntity,
          ListeningEventEntity,
          QFilterCondition
        > {}

extension ListeningEventEntityQueryLinks
    on
        QueryBuilder<
          ListeningEventEntity,
          ListeningEventEntity,
          QFilterCondition
        > {}

extension ListeningEventEntityQuerySortBy
    on QueryBuilder<ListeningEventEntity, ListeningEventEntity, QSortBy> {
  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterSortBy>
  sortByAlbum() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'album', Sort.asc);
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterSortBy>
  sortByAlbumDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'album', Sort.desc);
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterSortBy>
  sortByArtist() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'artist', Sort.asc);
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterSortBy>
  sortByArtistDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'artist', Sort.desc);
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterSortBy>
  sortByCompletedRatio() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedRatio', Sort.asc);
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterSortBy>
  sortByCompletedRatioDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedRatio', Sort.desc);
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterSortBy>
  sortByListenedMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'listenedMs', Sort.asc);
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterSortBy>
  sortByListenedMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'listenedMs', Sort.desc);
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterSortBy>
  sortByPlayedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'playedAt', Sort.asc);
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterSortBy>
  sortByPlayedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'playedAt', Sort.desc);
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterSortBy>
  sortBySessionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionId', Sort.asc);
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterSortBy>
  sortBySessionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionId', Sort.desc);
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterSortBy>
  sortBySongId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'songId', Sort.asc);
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterSortBy>
  sortBySongIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'songId', Sort.desc);
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterSortBy>
  sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterSortBy>
  sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }
}

extension ListeningEventEntityQuerySortThenBy
    on QueryBuilder<ListeningEventEntity, ListeningEventEntity, QSortThenBy> {
  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterSortBy>
  thenByAlbum() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'album', Sort.asc);
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterSortBy>
  thenByAlbumDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'album', Sort.desc);
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterSortBy>
  thenByArtist() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'artist', Sort.asc);
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterSortBy>
  thenByArtistDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'artist', Sort.desc);
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterSortBy>
  thenByCompletedRatio() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedRatio', Sort.asc);
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterSortBy>
  thenByCompletedRatioDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedRatio', Sort.desc);
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterSortBy>
  thenByListenedMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'listenedMs', Sort.asc);
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterSortBy>
  thenByListenedMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'listenedMs', Sort.desc);
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterSortBy>
  thenByPlayedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'playedAt', Sort.asc);
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterSortBy>
  thenByPlayedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'playedAt', Sort.desc);
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterSortBy>
  thenBySessionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionId', Sort.asc);
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterSortBy>
  thenBySessionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionId', Sort.desc);
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterSortBy>
  thenBySongId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'songId', Sort.asc);
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterSortBy>
  thenBySongIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'songId', Sort.desc);
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterSortBy>
  thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QAfterSortBy>
  thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }
}

extension ListeningEventEntityQueryWhereDistinct
    on QueryBuilder<ListeningEventEntity, ListeningEventEntity, QDistinct> {
  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QDistinct>
  distinctByAlbum({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'album', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QDistinct>
  distinctByArtist({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'artist', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QDistinct>
  distinctByCompletedRatio() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'completedRatio');
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QDistinct>
  distinctByListenedMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'listenedMs');
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QDistinct>
  distinctByPlayedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'playedAt');
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QDistinct>
  distinctBySessionId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sessionId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QDistinct>
  distinctBySongId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'songId');
    });
  }

  QueryBuilder<ListeningEventEntity, ListeningEventEntity, QDistinct>
  distinctByTitle({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }
}

extension ListeningEventEntityQueryProperty
    on
        QueryBuilder<
          ListeningEventEntity,
          ListeningEventEntity,
          QQueryProperty
        > {
  QueryBuilder<ListeningEventEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ListeningEventEntity, String, QQueryOperations> albumProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'album');
    });
  }

  QueryBuilder<ListeningEventEntity, String, QQueryOperations>
  artistProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'artist');
    });
  }

  QueryBuilder<ListeningEventEntity, double, QQueryOperations>
  completedRatioProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'completedRatio');
    });
  }

  QueryBuilder<ListeningEventEntity, int, QQueryOperations>
  listenedMsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'listenedMs');
    });
  }

  QueryBuilder<ListeningEventEntity, DateTime, QQueryOperations>
  playedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'playedAt');
    });
  }

  QueryBuilder<ListeningEventEntity, String, QQueryOperations>
  sessionIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sessionId');
    });
  }

  QueryBuilder<ListeningEventEntity, int, QQueryOperations> songIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'songId');
    });
  }

  QueryBuilder<ListeningEventEntity, String, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }
}
