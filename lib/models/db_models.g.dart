// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'db_models.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetTripCollection on Isar {
  IsarCollection<Trip> get trips => this.collection();
}

const TripSchema = CollectionSchema(
  name: r'Trip',
  id: 2639069002795865543,
  properties: {
    r'algorithm': PropertySchema(
      id: 0,
      name: r'algorithm',
      type: IsarType.string,
    ),
    r'appVersion': PropertySchema(
      id: 1,
      name: r'appVersion',
      type: IsarType.string,
    ),
    r'brand': PropertySchema(
      id: 2,
      name: r'brand',
      type: IsarType.string,
    ),
    r'brand_ref': PropertySchema(
      id: 3,
      name: r'brand_ref',
      type: IsarType.string,
    ),
    r'carModel': PropertySchema(
      id: 4,
      name: r'carModel',
      type: IsarType.string,
    ),
    r'cloudId': PropertySchema(
      id: 5,
      name: r'cloudId',
      type: IsarType.string,
    ),
    r'cloudMetrics': PropertySchema(
      id: 6,
      name: r'cloudMetrics',
      type: IsarType.string,
    ),
    r'distance': PropertySchema(
      id: 7,
      name: r'distance',
      type: IsarType.double,
    ),
    r'endTime': PropertySchema(
      id: 8,
      name: r'endTime',
      type: IsarType.dateTime,
    ),
    r'eventCount': PropertySchema(
      id: 9,
      name: r'eventCount',
      type: IsarType.long,
    ),
    r'eventStatsJson': PropertySchema(
      id: 10,
      name: r'eventStatsJson',
      type: IsarType.string,
    ),
    r'isDataSufficient': PropertySchema(
      id: 11,
      name: r'isDataSufficient',
      type: IsarType.bool,
    ),
    r'isLocalMissing': PropertySchema(
      id: 12,
      name: r'isLocalMissing',
      type: IsarType.bool,
    ),
    r'isUploaded': PropertySchema(
      id: 13,
      name: r'isUploaded',
      type: IsarType.bool,
    ),
    r'metrics': PropertySchema(
      id: 14,
      name: r'metrics',
      type: IsarType.string,
    ),
    r'metricsJson': PropertySchema(
      id: 15,
      name: r'metricsJson',
      type: IsarType.string,
    ),
    r'notes': PropertySchema(
      id: 16,
      name: r'notes',
      type: IsarType.string,
    ),
    r'platform': PropertySchema(
      id: 17,
      name: r'platform',
      type: IsarType.string,
    ),
    r'softwareVersion': PropertySchema(
      id: 18,
      name: r'softwareVersion',
      type: IsarType.string,
    ),
    r'software_version_ref': PropertySchema(
      id: 19,
      name: r'software_version_ref',
      type: IsarType.string,
    ),
    r'startTime': PropertySchema(
      id: 20,
      name: r'startTime',
      type: IsarType.dateTime,
    ),
    r'uuid': PropertySchema(
      id: 21,
      name: r'uuid',
      type: IsarType.string,
    )
  },
  estimateSize: _tripEstimateSize,
  serialize: _tripSerialize,
  deserialize: _tripDeserialize,
  deserializeProp: _tripDeserializeProp,
  idName: r'id',
  indexes: {
    r'uuid': IndexSchema(
      id: 2134397340427724972,
      name: r'uuid',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'uuid',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {
    r'trajectory': LinkSchema(
      id: 6476624287102088579,
      name: r'trajectory',
      target: r'TrajectoryPoint',
      single: false,
    ),
    r'events': LinkSchema(
      id: 5779037320085540316,
      name: r'events',
      target: r'RecordedEvent',
      single: false,
    )
  },
  embeddedSchemas: {},
  getId: _tripGetId,
  getLinks: _tripGetLinks,
  attach: _tripAttach,
  version: '3.1.0+1',
);

int _tripEstimateSize(
  Trip object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.algorithm;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.appVersion;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.brand;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.brand_ref;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.carModel;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.cloudId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.cloudMetrics;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.eventStatsJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.metrics;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.metricsJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.notes;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.platform;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.softwareVersion;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.software_version_ref;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.uuid.length * 3;
  return bytesCount;
}

void _tripSerialize(
  Trip object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.algorithm);
  writer.writeString(offsets[1], object.appVersion);
  writer.writeString(offsets[2], object.brand);
  writer.writeString(offsets[3], object.brand_ref);
  writer.writeString(offsets[4], object.carModel);
  writer.writeString(offsets[5], object.cloudId);
  writer.writeString(offsets[6], object.cloudMetrics);
  writer.writeDouble(offsets[7], object.distance);
  writer.writeDateTime(offsets[8], object.endTime);
  writer.writeLong(offsets[9], object.eventCount);
  writer.writeString(offsets[10], object.eventStatsJson);
  writer.writeBool(offsets[11], object.isDataSufficient);
  writer.writeBool(offsets[12], object.isLocalMissing);
  writer.writeBool(offsets[13], object.isUploaded);
  writer.writeString(offsets[14], object.metrics);
  writer.writeString(offsets[15], object.metricsJson);
  writer.writeString(offsets[16], object.notes);
  writer.writeString(offsets[17], object.platform);
  writer.writeString(offsets[18], object.softwareVersion);
  writer.writeString(offsets[19], object.software_version_ref);
  writer.writeDateTime(offsets[20], object.startTime);
  writer.writeString(offsets[21], object.uuid);
}

Trip _tripDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Trip();
  object.algorithm = reader.readStringOrNull(offsets[0]);
  object.appVersion = reader.readStringOrNull(offsets[1]);
  object.brand = reader.readStringOrNull(offsets[2]);
  object.brand_ref = reader.readStringOrNull(offsets[3]);
  object.carModel = reader.readStringOrNull(offsets[4]);
  object.cloudId = reader.readStringOrNull(offsets[5]);
  object.cloudMetrics = reader.readStringOrNull(offsets[6]);
  object.distance = reader.readDouble(offsets[7]);
  object.endTime = reader.readDateTimeOrNull(offsets[8]);
  object.eventCount = reader.readLong(offsets[9]);
  object.eventStatsJson = reader.readStringOrNull(offsets[10]);
  object.id = id;
  object.isLocalMissing = reader.readBool(offsets[12]);
  object.isUploaded = reader.readBool(offsets[13]);
  object.metrics = reader.readStringOrNull(offsets[14]);
  object.metricsJson = reader.readStringOrNull(offsets[15]);
  object.notes = reader.readStringOrNull(offsets[16]);
  object.platform = reader.readStringOrNull(offsets[17]);
  object.softwareVersion = reader.readStringOrNull(offsets[18]);
  object.software_version_ref = reader.readStringOrNull(offsets[19]);
  object.startTime = reader.readDateTime(offsets[20]);
  object.uuid = reader.readString(offsets[21]);
  return object;
}

P _tripDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    case 7:
      return (reader.readDouble(offset)) as P;
    case 8:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 9:
      return (reader.readLong(offset)) as P;
    case 10:
      return (reader.readStringOrNull(offset)) as P;
    case 11:
      return (reader.readBool(offset)) as P;
    case 12:
      return (reader.readBool(offset)) as P;
    case 13:
      return (reader.readBool(offset)) as P;
    case 14:
      return (reader.readStringOrNull(offset)) as P;
    case 15:
      return (reader.readStringOrNull(offset)) as P;
    case 16:
      return (reader.readStringOrNull(offset)) as P;
    case 17:
      return (reader.readStringOrNull(offset)) as P;
    case 18:
      return (reader.readStringOrNull(offset)) as P;
    case 19:
      return (reader.readStringOrNull(offset)) as P;
    case 20:
      return (reader.readDateTime(offset)) as P;
    case 21:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _tripGetId(Trip object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _tripGetLinks(Trip object) {
  return [object.trajectory, object.events];
}

void _tripAttach(IsarCollection<dynamic> col, Id id, Trip object) {
  object.id = id;
  object.trajectory
      .attach(col, col.isar.collection<TrajectoryPoint>(), r'trajectory', id);
  object.events
      .attach(col, col.isar.collection<RecordedEvent>(), r'events', id);
}

extension TripByIndex on IsarCollection<Trip> {
  Future<Trip?> getByUuid(String uuid) {
    return getByIndex(r'uuid', [uuid]);
  }

  Trip? getByUuidSync(String uuid) {
    return getByIndexSync(r'uuid', [uuid]);
  }

  Future<bool> deleteByUuid(String uuid) {
    return deleteByIndex(r'uuid', [uuid]);
  }

  bool deleteByUuidSync(String uuid) {
    return deleteByIndexSync(r'uuid', [uuid]);
  }

  Future<List<Trip?>> getAllByUuid(List<String> uuidValues) {
    final values = uuidValues.map((e) => [e]).toList();
    return getAllByIndex(r'uuid', values);
  }

  List<Trip?> getAllByUuidSync(List<String> uuidValues) {
    final values = uuidValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'uuid', values);
  }

  Future<int> deleteAllByUuid(List<String> uuidValues) {
    final values = uuidValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'uuid', values);
  }

  int deleteAllByUuidSync(List<String> uuidValues) {
    final values = uuidValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'uuid', values);
  }

  Future<Id> putByUuid(Trip object) {
    return putByIndex(r'uuid', object);
  }

  Id putByUuidSync(Trip object, {bool saveLinks = true}) {
    return putByIndexSync(r'uuid', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByUuid(List<Trip> objects) {
    return putAllByIndex(r'uuid', objects);
  }

  List<Id> putAllByUuidSync(List<Trip> objects, {bool saveLinks = true}) {
    return putAllByIndexSync(r'uuid', objects, saveLinks: saveLinks);
  }
}

extension TripQueryWhereSort on QueryBuilder<Trip, Trip, QWhere> {
  QueryBuilder<Trip, Trip, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension TripQueryWhere on QueryBuilder<Trip, Trip, QWhereClause> {
  QueryBuilder<Trip, Trip, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<Trip, Trip, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<Trip, Trip, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<Trip, Trip, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterWhereClause> uuidEqualTo(String uuid) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'uuid',
        value: [uuid],
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterWhereClause> uuidNotEqualTo(String uuid) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'uuid',
              lower: [],
              upper: [uuid],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'uuid',
              lower: [uuid],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'uuid',
              lower: [uuid],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'uuid',
              lower: [],
              upper: [uuid],
              includeUpper: false,
            ));
      }
    });
  }
}

extension TripQueryFilter on QueryBuilder<Trip, Trip, QFilterCondition> {
  QueryBuilder<Trip, Trip, QAfterFilterCondition> algorithmIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'algorithm',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> algorithmIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'algorithm',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> algorithmEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'algorithm',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> algorithmGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'algorithm',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> algorithmLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'algorithm',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> algorithmBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'algorithm',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> algorithmStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'algorithm',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> algorithmEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'algorithm',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> algorithmContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'algorithm',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> algorithmMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'algorithm',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> algorithmIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'algorithm',
        value: '',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> algorithmIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'algorithm',
        value: '',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> appVersionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'appVersion',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> appVersionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'appVersion',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> appVersionEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'appVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> appVersionGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'appVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> appVersionLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'appVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> appVersionBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'appVersion',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> appVersionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'appVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> appVersionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'appVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> appVersionContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'appVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> appVersionMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'appVersion',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> appVersionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'appVersion',
        value: '',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> appVersionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'appVersion',
        value: '',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> brandIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'brand',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> brandIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'brand',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> brandEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'brand',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> brandGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'brand',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> brandLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'brand',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> brandBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'brand',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> brandStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'brand',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> brandEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'brand',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> brandContains(String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'brand',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> brandMatches(String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'brand',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> brandIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'brand',
        value: '',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> brandIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'brand',
        value: '',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> brand_refIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'brand_ref',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> brand_refIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'brand_ref',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> brand_refEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'brand_ref',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> brand_refGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'brand_ref',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> brand_refLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'brand_ref',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> brand_refBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'brand_ref',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> brand_refStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'brand_ref',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> brand_refEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'brand_ref',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> brand_refContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'brand_ref',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> brand_refMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'brand_ref',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> brand_refIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'brand_ref',
        value: '',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> brand_refIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'brand_ref',
        value: '',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> carModelIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'carModel',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> carModelIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'carModel',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> carModelEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'carModel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> carModelGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'carModel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> carModelLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'carModel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> carModelBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'carModel',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> carModelStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'carModel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> carModelEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'carModel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> carModelContains(String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'carModel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> carModelMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'carModel',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> carModelIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'carModel',
        value: '',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> carModelIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'carModel',
        value: '',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> cloudIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'cloudId',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> cloudIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'cloudId',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> cloudIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cloudId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> cloudIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'cloudId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> cloudIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'cloudId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> cloudIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'cloudId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> cloudIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'cloudId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> cloudIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'cloudId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> cloudIdContains(String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'cloudId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> cloudIdMatches(String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'cloudId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> cloudIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cloudId',
        value: '',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> cloudIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'cloudId',
        value: '',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> cloudMetricsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'cloudMetrics',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> cloudMetricsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'cloudMetrics',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> cloudMetricsEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cloudMetrics',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> cloudMetricsGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'cloudMetrics',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> cloudMetricsLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'cloudMetrics',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> cloudMetricsBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'cloudMetrics',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> cloudMetricsStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'cloudMetrics',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> cloudMetricsEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'cloudMetrics',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> cloudMetricsContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'cloudMetrics',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> cloudMetricsMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'cloudMetrics',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> cloudMetricsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cloudMetrics',
        value: '',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> cloudMetricsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'cloudMetrics',
        value: '',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> distanceEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'distance',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> distanceGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'distance',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> distanceLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'distance',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> distanceBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'distance',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> endTimeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'endTime',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> endTimeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'endTime',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> endTimeEqualTo(
      DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'endTime',
        value: value,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> endTimeGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'endTime',
        value: value,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> endTimeLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'endTime',
        value: value,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> endTimeBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'endTime',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> eventCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'eventCount',
        value: value,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> eventCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'eventCount',
        value: value,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> eventCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'eventCount',
        value: value,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> eventCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'eventCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> eventStatsJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'eventStatsJson',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> eventStatsJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'eventStatsJson',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> eventStatsJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'eventStatsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> eventStatsJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'eventStatsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> eventStatsJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'eventStatsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> eventStatsJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'eventStatsJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> eventStatsJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'eventStatsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> eventStatsJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'eventStatsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> eventStatsJsonContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'eventStatsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> eventStatsJsonMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'eventStatsJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> eventStatsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'eventStatsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> eventStatsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'eventStatsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> isDataSufficientEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isDataSufficient',
        value: value,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> isLocalMissingEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isLocalMissing',
        value: value,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> isUploadedEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isUploaded',
        value: value,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> metricsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'metrics',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> metricsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'metrics',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> metricsEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'metrics',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> metricsGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'metrics',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> metricsLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'metrics',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> metricsBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'metrics',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> metricsStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'metrics',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> metricsEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'metrics',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> metricsContains(String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'metrics',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> metricsMatches(String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'metrics',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> metricsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'metrics',
        value: '',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> metricsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'metrics',
        value: '',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> metricsJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'metricsJson',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> metricsJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'metricsJson',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> metricsJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'metricsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> metricsJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'metricsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> metricsJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'metricsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> metricsJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'metricsJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> metricsJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'metricsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> metricsJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'metricsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> metricsJsonContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'metricsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> metricsJsonMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'metricsJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> metricsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'metricsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> metricsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'metricsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> notesIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'notes',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> notesIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'notes',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> notesEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> notesGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> notesLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> notesBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'notes',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> notesStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> notesEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> notesContains(String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> notesMatches(String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'notes',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> notesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'notes',
        value: '',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> notesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'notes',
        value: '',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> platformIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'platform',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> platformIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'platform',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> platformEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'platform',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> platformGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'platform',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> platformLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'platform',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> platformBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'platform',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> platformStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'platform',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> platformEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'platform',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> platformContains(String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'platform',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> platformMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'platform',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> platformIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'platform',
        value: '',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> platformIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'platform',
        value: '',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> softwareVersionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'softwareVersion',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> softwareVersionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'softwareVersion',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> softwareVersionEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'softwareVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> softwareVersionGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'softwareVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> softwareVersionLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'softwareVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> softwareVersionBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'softwareVersion',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> softwareVersionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'softwareVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> softwareVersionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'softwareVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> softwareVersionContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'softwareVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> softwareVersionMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'softwareVersion',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> softwareVersionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'softwareVersion',
        value: '',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> softwareVersionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'softwareVersion',
        value: '',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> software_version_refIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'software_version_ref',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition>
      software_version_refIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'software_version_ref',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> software_version_refEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'software_version_ref',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition>
      software_version_refGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'software_version_ref',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> software_version_refLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'software_version_ref',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> software_version_refBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'software_version_ref',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition>
      software_version_refStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'software_version_ref',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> software_version_refEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'software_version_ref',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> software_version_refContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'software_version_ref',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> software_version_refMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'software_version_ref',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition>
      software_version_refIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'software_version_ref',
        value: '',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition>
      software_version_refIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'software_version_ref',
        value: '',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> startTimeEqualTo(
      DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'startTime',
        value: value,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> startTimeGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'startTime',
        value: value,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> startTimeLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'startTime',
        value: value,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> startTimeBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'startTime',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> uuidEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'uuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> uuidGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'uuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> uuidLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'uuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> uuidBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'uuid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> uuidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'uuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> uuidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'uuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> uuidContains(String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'uuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> uuidMatches(String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'uuid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> uuidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'uuid',
        value: '',
      ));
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> uuidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'uuid',
        value: '',
      ));
    });
  }
}

extension TripQueryObject on QueryBuilder<Trip, Trip, QFilterCondition> {}

extension TripQueryLinks on QueryBuilder<Trip, Trip, QFilterCondition> {
  QueryBuilder<Trip, Trip, QAfterFilterCondition> trajectory(
      FilterQuery<TrajectoryPoint> q) {
    return QueryBuilder.apply(this, (query) {
      return query.link(q, r'trajectory');
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> trajectoryLengthEqualTo(
      int length) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'trajectory', length, true, length, true);
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> trajectoryIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'trajectory', 0, true, 0, true);
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> trajectoryIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'trajectory', 0, false, 999999, true);
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> trajectoryLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'trajectory', 0, true, length, include);
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> trajectoryLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'trajectory', length, include, 999999, true);
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> trajectoryLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(
          r'trajectory', lower, includeLower, upper, includeUpper);
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> events(
      FilterQuery<RecordedEvent> q) {
    return QueryBuilder.apply(this, (query) {
      return query.link(q, r'events');
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> eventsLengthEqualTo(
      int length) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'events', length, true, length, true);
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> eventsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'events', 0, true, 0, true);
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> eventsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'events', 0, false, 999999, true);
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> eventsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'events', 0, true, length, include);
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> eventsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'events', length, include, 999999, true);
    });
  }

  QueryBuilder<Trip, Trip, QAfterFilterCondition> eventsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(
          r'events', lower, includeLower, upper, includeUpper);
    });
  }
}

extension TripQuerySortBy on QueryBuilder<Trip, Trip, QSortBy> {
  QueryBuilder<Trip, Trip, QAfterSortBy> sortByAlgorithm() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'algorithm', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortByAlgorithmDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'algorithm', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortByAppVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appVersion', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortByAppVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appVersion', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortByBrand() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'brand', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortByBrandDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'brand', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortByBrand_ref() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'brand_ref', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortByBrand_refDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'brand_ref', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortByCarModel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'carModel', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortByCarModelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'carModel', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortByCloudId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cloudId', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortByCloudIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cloudId', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortByCloudMetrics() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cloudMetrics', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortByCloudMetricsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cloudMetrics', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortByDistance() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'distance', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortByDistanceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'distance', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortByEndTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endTime', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortByEndTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endTime', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortByEventCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventCount', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortByEventCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventCount', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortByEventStatsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventStatsJson', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortByEventStatsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventStatsJson', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortByIsDataSufficient() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDataSufficient', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortByIsDataSufficientDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDataSufficient', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortByIsLocalMissing() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isLocalMissing', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortByIsLocalMissingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isLocalMissing', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortByIsUploaded() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isUploaded', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortByIsUploadedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isUploaded', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortByMetrics() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metrics', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortByMetricsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metrics', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortByMetricsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metricsJson', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortByMetricsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metricsJson', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortByNotes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortByNotesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortByPlatform() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'platform', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortByPlatformDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'platform', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortBySoftwareVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'softwareVersion', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortBySoftwareVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'softwareVersion', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortBySoftware_version_ref() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'software_version_ref', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortBySoftware_version_refDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'software_version_ref', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortByStartTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startTime', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortByStartTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startTime', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortByUuid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uuid', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> sortByUuidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uuid', Sort.desc);
    });
  }
}

extension TripQuerySortThenBy on QueryBuilder<Trip, Trip, QSortThenBy> {
  QueryBuilder<Trip, Trip, QAfterSortBy> thenByAlgorithm() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'algorithm', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenByAlgorithmDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'algorithm', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenByAppVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appVersion', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenByAppVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appVersion', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenByBrand() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'brand', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenByBrandDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'brand', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenByBrand_ref() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'brand_ref', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenByBrand_refDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'brand_ref', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenByCarModel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'carModel', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenByCarModelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'carModel', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenByCloudId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cloudId', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenByCloudIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cloudId', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenByCloudMetrics() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cloudMetrics', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenByCloudMetricsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cloudMetrics', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenByDistance() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'distance', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenByDistanceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'distance', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenByEndTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endTime', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenByEndTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endTime', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenByEventCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventCount', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenByEventCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventCount', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenByEventStatsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventStatsJson', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenByEventStatsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventStatsJson', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenByIsDataSufficient() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDataSufficient', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenByIsDataSufficientDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDataSufficient', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenByIsLocalMissing() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isLocalMissing', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenByIsLocalMissingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isLocalMissing', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenByIsUploaded() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isUploaded', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenByIsUploadedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isUploaded', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenByMetrics() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metrics', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenByMetricsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metrics', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenByMetricsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metricsJson', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenByMetricsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metricsJson', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenByNotes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenByNotesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenByPlatform() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'platform', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenByPlatformDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'platform', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenBySoftwareVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'softwareVersion', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenBySoftwareVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'softwareVersion', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenBySoftware_version_ref() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'software_version_ref', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenBySoftware_version_refDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'software_version_ref', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenByStartTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startTime', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenByStartTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startTime', Sort.desc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenByUuid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uuid', Sort.asc);
    });
  }

  QueryBuilder<Trip, Trip, QAfterSortBy> thenByUuidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uuid', Sort.desc);
    });
  }
}

extension TripQueryWhereDistinct on QueryBuilder<Trip, Trip, QDistinct> {
  QueryBuilder<Trip, Trip, QDistinct> distinctByAlgorithm(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'algorithm', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Trip, Trip, QDistinct> distinctByAppVersion(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'appVersion', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Trip, Trip, QDistinct> distinctByBrand(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'brand', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Trip, Trip, QDistinct> distinctByBrand_ref(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'brand_ref', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Trip, Trip, QDistinct> distinctByCarModel(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'carModel', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Trip, Trip, QDistinct> distinctByCloudId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cloudId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Trip, Trip, QDistinct> distinctByCloudMetrics(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cloudMetrics', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Trip, Trip, QDistinct> distinctByDistance() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'distance');
    });
  }

  QueryBuilder<Trip, Trip, QDistinct> distinctByEndTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'endTime');
    });
  }

  QueryBuilder<Trip, Trip, QDistinct> distinctByEventCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'eventCount');
    });
  }

  QueryBuilder<Trip, Trip, QDistinct> distinctByEventStatsJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'eventStatsJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Trip, Trip, QDistinct> distinctByIsDataSufficient() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isDataSufficient');
    });
  }

  QueryBuilder<Trip, Trip, QDistinct> distinctByIsLocalMissing() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isLocalMissing');
    });
  }

  QueryBuilder<Trip, Trip, QDistinct> distinctByIsUploaded() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isUploaded');
    });
  }

  QueryBuilder<Trip, Trip, QDistinct> distinctByMetrics(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'metrics', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Trip, Trip, QDistinct> distinctByMetricsJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'metricsJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Trip, Trip, QDistinct> distinctByNotes(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'notes', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Trip, Trip, QDistinct> distinctByPlatform(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'platform', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Trip, Trip, QDistinct> distinctBySoftwareVersion(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'softwareVersion',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Trip, Trip, QDistinct> distinctBySoftware_version_ref(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'software_version_ref',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Trip, Trip, QDistinct> distinctByStartTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'startTime');
    });
  }

  QueryBuilder<Trip, Trip, QDistinct> distinctByUuid(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'uuid', caseSensitive: caseSensitive);
    });
  }
}

extension TripQueryProperty on QueryBuilder<Trip, Trip, QQueryProperty> {
  QueryBuilder<Trip, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Trip, String?, QQueryOperations> algorithmProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'algorithm');
    });
  }

  QueryBuilder<Trip, String?, QQueryOperations> appVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'appVersion');
    });
  }

  QueryBuilder<Trip, String?, QQueryOperations> brandProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'brand');
    });
  }

  QueryBuilder<Trip, String?, QQueryOperations> brand_refProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'brand_ref');
    });
  }

  QueryBuilder<Trip, String?, QQueryOperations> carModelProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'carModel');
    });
  }

  QueryBuilder<Trip, String?, QQueryOperations> cloudIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cloudId');
    });
  }

  QueryBuilder<Trip, String?, QQueryOperations> cloudMetricsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cloudMetrics');
    });
  }

  QueryBuilder<Trip, double, QQueryOperations> distanceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'distance');
    });
  }

  QueryBuilder<Trip, DateTime?, QQueryOperations> endTimeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'endTime');
    });
  }

  QueryBuilder<Trip, int, QQueryOperations> eventCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'eventCount');
    });
  }

  QueryBuilder<Trip, String?, QQueryOperations> eventStatsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'eventStatsJson');
    });
  }

  QueryBuilder<Trip, bool, QQueryOperations> isDataSufficientProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isDataSufficient');
    });
  }

  QueryBuilder<Trip, bool, QQueryOperations> isLocalMissingProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isLocalMissing');
    });
  }

  QueryBuilder<Trip, bool, QQueryOperations> isUploadedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isUploaded');
    });
  }

  QueryBuilder<Trip, String?, QQueryOperations> metricsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'metrics');
    });
  }

  QueryBuilder<Trip, String?, QQueryOperations> metricsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'metricsJson');
    });
  }

  QueryBuilder<Trip, String?, QQueryOperations> notesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'notes');
    });
  }

  QueryBuilder<Trip, String?, QQueryOperations> platformProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'platform');
    });
  }

  QueryBuilder<Trip, String?, QQueryOperations> softwareVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'softwareVersion');
    });
  }

  QueryBuilder<Trip, String?, QQueryOperations> software_version_refProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'software_version_ref');
    });
  }

  QueryBuilder<Trip, DateTime, QQueryOperations> startTimeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'startTime');
    });
  }

  QueryBuilder<Trip, String, QQueryOperations> uuidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'uuid');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetTrajectoryPointCollection on Isar {
  IsarCollection<TrajectoryPoint> get trajectoryPoints => this.collection();
}

const TrajectoryPointSchema = CollectionSchema(
  name: r'TrajectoryPoint',
  id: -5473406979912383196,
  properties: {
    r'altitude': PropertySchema(
      id: 0,
      name: r'altitude',
      type: IsarType.double,
    ),
    r'ax': PropertySchema(
      id: 1,
      name: r'ax',
      type: IsarType.double,
    ),
    r'ay': PropertySchema(
      id: 2,
      name: r'ay',
      type: IsarType.double,
    ),
    r'az': PropertySchema(
      id: 3,
      name: r'az',
      type: IsarType.double,
    ),
    r'gx': PropertySchema(
      id: 4,
      name: r'gx',
      type: IsarType.double,
    ),
    r'gy': PropertySchema(
      id: 5,
      name: r'gy',
      type: IsarType.double,
    ),
    r'gz': PropertySchema(
      id: 6,
      name: r'gz',
      type: IsarType.double,
    ),
    r'isLowConfidence': PropertySchema(
      id: 7,
      name: r'isLowConfidence',
      type: IsarType.bool,
    ),
    r'lat': PropertySchema(
      id: 8,
      name: r'lat',
      type: IsarType.double,
    ),
    r'lng': PropertySchema(
      id: 9,
      name: r'lng',
      type: IsarType.double,
    ),
    r'speed': PropertySchema(
      id: 10,
      name: r'speed',
      type: IsarType.double,
    ),
    r'timestamp': PropertySchema(
      id: 11,
      name: r'timestamp',
      type: IsarType.dateTime,
    )
  },
  estimateSize: _trajectoryPointEstimateSize,
  serialize: _trajectoryPointSerialize,
  deserialize: _trajectoryPointDeserialize,
  deserializeProp: _trajectoryPointDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _trajectoryPointGetId,
  getLinks: _trajectoryPointGetLinks,
  attach: _trajectoryPointAttach,
  version: '3.1.0+1',
);

int _trajectoryPointEstimateSize(
  TrajectoryPoint object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  return bytesCount;
}

void _trajectoryPointSerialize(
  TrajectoryPoint object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDouble(offsets[0], object.altitude);
  writer.writeDouble(offsets[1], object.ax);
  writer.writeDouble(offsets[2], object.ay);
  writer.writeDouble(offsets[3], object.az);
  writer.writeDouble(offsets[4], object.gx);
  writer.writeDouble(offsets[5], object.gy);
  writer.writeDouble(offsets[6], object.gz);
  writer.writeBool(offsets[7], object.isLowConfidence);
  writer.writeDouble(offsets[8], object.lat);
  writer.writeDouble(offsets[9], object.lng);
  writer.writeDouble(offsets[10], object.speed);
  writer.writeDateTime(offsets[11], object.timestamp);
}

TrajectoryPoint _trajectoryPointDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = TrajectoryPoint();
  object.altitude = reader.readDouble(offsets[0]);
  object.ax = reader.readDoubleOrNull(offsets[1]);
  object.ay = reader.readDoubleOrNull(offsets[2]);
  object.az = reader.readDoubleOrNull(offsets[3]);
  object.gx = reader.readDoubleOrNull(offsets[4]);
  object.gy = reader.readDoubleOrNull(offsets[5]);
  object.gz = reader.readDoubleOrNull(offsets[6]);
  object.id = id;
  object.isLowConfidence = reader.readBool(offsets[7]);
  object.lat = reader.readDouble(offsets[8]);
  object.lng = reader.readDouble(offsets[9]);
  object.speed = reader.readDouble(offsets[10]);
  object.timestamp = reader.readDateTime(offsets[11]);
  return object;
}

P _trajectoryPointDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDouble(offset)) as P;
    case 1:
      return (reader.readDoubleOrNull(offset)) as P;
    case 2:
      return (reader.readDoubleOrNull(offset)) as P;
    case 3:
      return (reader.readDoubleOrNull(offset)) as P;
    case 4:
      return (reader.readDoubleOrNull(offset)) as P;
    case 5:
      return (reader.readDoubleOrNull(offset)) as P;
    case 6:
      return (reader.readDoubleOrNull(offset)) as P;
    case 7:
      return (reader.readBool(offset)) as P;
    case 8:
      return (reader.readDouble(offset)) as P;
    case 9:
      return (reader.readDouble(offset)) as P;
    case 10:
      return (reader.readDouble(offset)) as P;
    case 11:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _trajectoryPointGetId(TrajectoryPoint object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _trajectoryPointGetLinks(TrajectoryPoint object) {
  return [];
}

void _trajectoryPointAttach(
    IsarCollection<dynamic> col, Id id, TrajectoryPoint object) {
  object.id = id;
}

extension TrajectoryPointQueryWhereSort
    on QueryBuilder<TrajectoryPoint, TrajectoryPoint, QWhere> {
  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension TrajectoryPointQueryWhere
    on QueryBuilder<TrajectoryPoint, TrajectoryPoint, QWhereClause> {
  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterWhereClause>
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

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension TrajectoryPointQueryFilter
    on QueryBuilder<TrajectoryPoint, TrajectoryPoint, QFilterCondition> {
  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      altitudeEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'altitude',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      altitudeGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'altitude',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      altitudeLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'altitude',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      altitudeBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'altitude',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      axIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'ax',
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      axIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'ax',
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      axEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ax',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      axGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'ax',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      axLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'ax',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      axBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'ax',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      ayIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'ay',
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      ayIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'ay',
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      ayEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ay',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      ayGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'ay',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      ayLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'ay',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      ayBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'ay',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      azIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'az',
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      azIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'az',
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      azEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'az',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      azGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'az',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      azLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'az',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      azBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'az',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      gxIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'gx',
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      gxIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'gx',
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      gxEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'gx',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      gxGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'gx',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      gxLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'gx',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      gxBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'gx',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      gyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'gy',
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      gyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'gy',
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      gyEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'gy',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      gyGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'gy',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      gyLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'gy',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      gyBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'gy',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      gzIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'gz',
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      gzIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'gz',
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      gzEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'gz',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      gzGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'gz',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      gzLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'gz',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      gzBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'gz',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      isLowConfidenceEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isLowConfidence',
        value: value,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      latEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lat',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      latGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lat',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      latLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lat',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      latBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lat',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      lngEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lng',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      lngGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lng',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      lngLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lng',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      lngBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lng',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      speedEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'speed',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      speedGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'speed',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      speedLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'speed',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      speedBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'speed',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      timestampEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'timestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      timestampGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'timestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      timestampLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'timestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterFilterCondition>
      timestampBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'timestamp',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension TrajectoryPointQueryObject
    on QueryBuilder<TrajectoryPoint, TrajectoryPoint, QFilterCondition> {}

extension TrajectoryPointQueryLinks
    on QueryBuilder<TrajectoryPoint, TrajectoryPoint, QFilterCondition> {}

extension TrajectoryPointQuerySortBy
    on QueryBuilder<TrajectoryPoint, TrajectoryPoint, QSortBy> {
  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy>
      sortByAltitude() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'altitude', Sort.asc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy>
      sortByAltitudeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'altitude', Sort.desc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy> sortByAx() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ax', Sort.asc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy> sortByAxDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ax', Sort.desc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy> sortByAy() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ay', Sort.asc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy> sortByAyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ay', Sort.desc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy> sortByAz() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'az', Sort.asc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy> sortByAzDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'az', Sort.desc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy> sortByGx() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'gx', Sort.asc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy> sortByGxDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'gx', Sort.desc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy> sortByGy() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'gy', Sort.asc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy> sortByGyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'gy', Sort.desc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy> sortByGz() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'gz', Sort.asc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy> sortByGzDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'gz', Sort.desc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy>
      sortByIsLowConfidence() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isLowConfidence', Sort.asc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy>
      sortByIsLowConfidenceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isLowConfidence', Sort.desc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy> sortByLat() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lat', Sort.asc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy> sortByLatDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lat', Sort.desc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy> sortByLng() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lng', Sort.asc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy> sortByLngDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lng', Sort.desc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy> sortBySpeed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'speed', Sort.asc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy>
      sortBySpeedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'speed', Sort.desc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy>
      sortByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy>
      sortByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }
}

extension TrajectoryPointQuerySortThenBy
    on QueryBuilder<TrajectoryPoint, TrajectoryPoint, QSortThenBy> {
  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy>
      thenByAltitude() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'altitude', Sort.asc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy>
      thenByAltitudeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'altitude', Sort.desc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy> thenByAx() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ax', Sort.asc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy> thenByAxDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ax', Sort.desc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy> thenByAy() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ay', Sort.asc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy> thenByAyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ay', Sort.desc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy> thenByAz() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'az', Sort.asc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy> thenByAzDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'az', Sort.desc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy> thenByGx() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'gx', Sort.asc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy> thenByGxDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'gx', Sort.desc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy> thenByGy() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'gy', Sort.asc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy> thenByGyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'gy', Sort.desc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy> thenByGz() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'gz', Sort.asc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy> thenByGzDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'gz', Sort.desc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy>
      thenByIsLowConfidence() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isLowConfidence', Sort.asc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy>
      thenByIsLowConfidenceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isLowConfidence', Sort.desc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy> thenByLat() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lat', Sort.asc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy> thenByLatDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lat', Sort.desc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy> thenByLng() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lng', Sort.asc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy> thenByLngDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lng', Sort.desc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy> thenBySpeed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'speed', Sort.asc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy>
      thenBySpeedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'speed', Sort.desc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy>
      thenByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QAfterSortBy>
      thenByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }
}

extension TrajectoryPointQueryWhereDistinct
    on QueryBuilder<TrajectoryPoint, TrajectoryPoint, QDistinct> {
  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QDistinct>
      distinctByAltitude() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'altitude');
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QDistinct> distinctByAx() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ax');
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QDistinct> distinctByAy() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ay');
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QDistinct> distinctByAz() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'az');
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QDistinct> distinctByGx() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'gx');
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QDistinct> distinctByGy() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'gy');
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QDistinct> distinctByGz() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'gz');
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QDistinct>
      distinctByIsLowConfidence() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isLowConfidence');
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QDistinct> distinctByLat() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lat');
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QDistinct> distinctByLng() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lng');
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QDistinct> distinctBySpeed() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'speed');
    });
  }

  QueryBuilder<TrajectoryPoint, TrajectoryPoint, QDistinct>
      distinctByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'timestamp');
    });
  }
}

extension TrajectoryPointQueryProperty
    on QueryBuilder<TrajectoryPoint, TrajectoryPoint, QQueryProperty> {
  QueryBuilder<TrajectoryPoint, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<TrajectoryPoint, double, QQueryOperations> altitudeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'altitude');
    });
  }

  QueryBuilder<TrajectoryPoint, double?, QQueryOperations> axProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ax');
    });
  }

  QueryBuilder<TrajectoryPoint, double?, QQueryOperations> ayProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ay');
    });
  }

  QueryBuilder<TrajectoryPoint, double?, QQueryOperations> azProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'az');
    });
  }

  QueryBuilder<TrajectoryPoint, double?, QQueryOperations> gxProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'gx');
    });
  }

  QueryBuilder<TrajectoryPoint, double?, QQueryOperations> gyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'gy');
    });
  }

  QueryBuilder<TrajectoryPoint, double?, QQueryOperations> gzProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'gz');
    });
  }

  QueryBuilder<TrajectoryPoint, bool, QQueryOperations>
      isLowConfidenceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isLowConfidence');
    });
  }

  QueryBuilder<TrajectoryPoint, double, QQueryOperations> latProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lat');
    });
  }

  QueryBuilder<TrajectoryPoint, double, QQueryOperations> lngProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lng');
    });
  }

  QueryBuilder<TrajectoryPoint, double, QQueryOperations> speedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'speed');
    });
  }

  QueryBuilder<TrajectoryPoint, DateTime, QQueryOperations>
      timestampProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'timestamp');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetRecordedEventCollection on Isar {
  IsarCollection<RecordedEvent> get recordedEvents => this.collection();
}

const RecordedEventSchema = CollectionSchema(
  name: r'RecordedEvent',
  id: -4127872194806281009,
  properties: {
    r'gForce': PropertySchema(
      id: 0,
      name: r'gForce',
      type: IsarType.double,
    ),
    r'lat': PropertySchema(
      id: 1,
      name: r'lat',
      type: IsarType.double,
    ),
    r'lng': PropertySchema(
      id: 2,
      name: r'lng',
      type: IsarType.double,
    ),
    r'notes': PropertySchema(
      id: 3,
      name: r'notes',
      type: IsarType.string,
    ),
    r'sensorData': PropertySchema(
      id: 4,
      name: r'sensorData',
      type: IsarType.objectList,
      target: r'SensorPointEmbedded',
    ),
    r'source': PropertySchema(
      id: 5,
      name: r'source',
      type: IsarType.string,
    ),
    r'speed': PropertySchema(
      id: 6,
      name: r'speed',
      type: IsarType.double,
    ),
    r'timestamp': PropertySchema(
      id: 7,
      name: r'timestamp',
      type: IsarType.dateTime,
    ),
    r'type': PropertySchema(
      id: 8,
      name: r'type',
      type: IsarType.string,
    ),
    r'uuid': PropertySchema(
      id: 9,
      name: r'uuid',
      type: IsarType.string,
    ),
    r'voiceText': PropertySchema(
      id: 10,
      name: r'voiceText',
      type: IsarType.string,
    )
  },
  estimateSize: _recordedEventEstimateSize,
  serialize: _recordedEventSerialize,
  deserialize: _recordedEventDeserialize,
  deserializeProp: _recordedEventDeserializeProp,
  idName: r'id',
  indexes: {
    r'uuid': IndexSchema(
      id: 2134397340427724972,
      name: r'uuid',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'uuid',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {r'SensorPointEmbedded': SensorPointEmbeddedSchema},
  getId: _recordedEventGetId,
  getLinks: _recordedEventGetLinks,
  attach: _recordedEventAttach,
  version: '3.1.0+1',
);

int _recordedEventEstimateSize(
  RecordedEvent object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.notes;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.sensorData.length * 3;
  {
    final offsets = allOffsets[SensorPointEmbedded]!;
    for (var i = 0; i < object.sensorData.length; i++) {
      final value = object.sensorData[i];
      bytesCount +=
          SensorPointEmbeddedSchema.estimateSize(value, offsets, allOffsets);
    }
  }
  {
    final value = object.source;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.type.length * 3;
  bytesCount += 3 + object.uuid.length * 3;
  {
    final value = object.voiceText;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _recordedEventSerialize(
  RecordedEvent object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDouble(offsets[0], object.gForce);
  writer.writeDouble(offsets[1], object.lat);
  writer.writeDouble(offsets[2], object.lng);
  writer.writeString(offsets[3], object.notes);
  writer.writeObjectList<SensorPointEmbedded>(
    offsets[4],
    allOffsets,
    SensorPointEmbeddedSchema.serialize,
    object.sensorData,
  );
  writer.writeString(offsets[5], object.source);
  writer.writeDouble(offsets[6], object.speed);
  writer.writeDateTime(offsets[7], object.timestamp);
  writer.writeString(offsets[8], object.type);
  writer.writeString(offsets[9], object.uuid);
  writer.writeString(offsets[10], object.voiceText);
}

RecordedEvent _recordedEventDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = RecordedEvent();
  object.gForce = reader.readDoubleOrNull(offsets[0]);
  object.id = id;
  object.lat = reader.readDoubleOrNull(offsets[1]);
  object.lng = reader.readDoubleOrNull(offsets[2]);
  object.notes = reader.readStringOrNull(offsets[3]);
  object.sensorData = reader.readObjectList<SensorPointEmbedded>(
        offsets[4],
        SensorPointEmbeddedSchema.deserialize,
        allOffsets,
        SensorPointEmbedded(),
      ) ??
      [];
  object.source = reader.readStringOrNull(offsets[5]);
  object.speed = reader.readDoubleOrNull(offsets[6]);
  object.timestamp = reader.readDateTime(offsets[7]);
  object.type = reader.readString(offsets[8]);
  object.uuid = reader.readString(offsets[9]);
  object.voiceText = reader.readStringOrNull(offsets[10]);
  return object;
}

P _recordedEventDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDoubleOrNull(offset)) as P;
    case 1:
      return (reader.readDoubleOrNull(offset)) as P;
    case 2:
      return (reader.readDoubleOrNull(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readObjectList<SensorPointEmbedded>(
            offset,
            SensorPointEmbeddedSchema.deserialize,
            allOffsets,
            SensorPointEmbedded(),
          ) ??
          []) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readDoubleOrNull(offset)) as P;
    case 7:
      return (reader.readDateTime(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    case 10:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _recordedEventGetId(RecordedEvent object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _recordedEventGetLinks(RecordedEvent object) {
  return [];
}

void _recordedEventAttach(
    IsarCollection<dynamic> col, Id id, RecordedEvent object) {
  object.id = id;
}

extension RecordedEventByIndex on IsarCollection<RecordedEvent> {
  Future<RecordedEvent?> getByUuid(String uuid) {
    return getByIndex(r'uuid', [uuid]);
  }

  RecordedEvent? getByUuidSync(String uuid) {
    return getByIndexSync(r'uuid', [uuid]);
  }

  Future<bool> deleteByUuid(String uuid) {
    return deleteByIndex(r'uuid', [uuid]);
  }

  bool deleteByUuidSync(String uuid) {
    return deleteByIndexSync(r'uuid', [uuid]);
  }

  Future<List<RecordedEvent?>> getAllByUuid(List<String> uuidValues) {
    final values = uuidValues.map((e) => [e]).toList();
    return getAllByIndex(r'uuid', values);
  }

  List<RecordedEvent?> getAllByUuidSync(List<String> uuidValues) {
    final values = uuidValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'uuid', values);
  }

  Future<int> deleteAllByUuid(List<String> uuidValues) {
    final values = uuidValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'uuid', values);
  }

  int deleteAllByUuidSync(List<String> uuidValues) {
    final values = uuidValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'uuid', values);
  }

  Future<Id> putByUuid(RecordedEvent object) {
    return putByIndex(r'uuid', object);
  }

  Id putByUuidSync(RecordedEvent object, {bool saveLinks = true}) {
    return putByIndexSync(r'uuid', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByUuid(List<RecordedEvent> objects) {
    return putAllByIndex(r'uuid', objects);
  }

  List<Id> putAllByUuidSync(List<RecordedEvent> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'uuid', objects, saveLinks: saveLinks);
  }
}

extension RecordedEventQueryWhereSort
    on QueryBuilder<RecordedEvent, RecordedEvent, QWhere> {
  QueryBuilder<RecordedEvent, RecordedEvent, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension RecordedEventQueryWhere
    on QueryBuilder<RecordedEvent, RecordedEvent, QWhereClause> {
  QueryBuilder<RecordedEvent, RecordedEvent, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterWhereClause> idNotEqualTo(
      Id id) {
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

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterWhereClause> uuidEqualTo(
      String uuid) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'uuid',
        value: [uuid],
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterWhereClause> uuidNotEqualTo(
      String uuid) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'uuid',
              lower: [],
              upper: [uuid],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'uuid',
              lower: [uuid],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'uuid',
              lower: [uuid],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'uuid',
              lower: [],
              upper: [uuid],
              includeUpper: false,
            ));
      }
    });
  }
}

extension RecordedEventQueryFilter
    on QueryBuilder<RecordedEvent, RecordedEvent, QFilterCondition> {
  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      gForceIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'gForce',
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      gForceIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'gForce',
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      gForceEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'gForce',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      gForceGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'gForce',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      gForceLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'gForce',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      gForceBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'gForce',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      latIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lat',
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      latIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lat',
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition> latEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lat',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      latGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lat',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition> latLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lat',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition> latBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lat',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      lngIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lng',
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      lngIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lng',
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition> lngEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lng',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      lngGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lng',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition> lngLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lng',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition> lngBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lng',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      notesIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'notes',
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      notesIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'notes',
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      notesEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      notesGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      notesLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      notesBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'notes',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      notesStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      notesEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      notesContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      notesMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'notes',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      notesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'notes',
        value: '',
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      notesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'notes',
        value: '',
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      sensorDataLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'sensorData',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      sensorDataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'sensorData',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      sensorDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'sensorData',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      sensorDataLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'sensorData',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      sensorDataLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'sensorData',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      sensorDataLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'sensorData',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      sourceIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'source',
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      sourceIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'source',
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      sourceEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'source',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      sourceGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'source',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      sourceLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'source',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      sourceBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'source',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      sourceStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'source',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      sourceEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'source',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      sourceContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'source',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      sourceMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'source',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      sourceIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'source',
        value: '',
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      sourceIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'source',
        value: '',
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      speedIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'speed',
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      speedIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'speed',
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      speedEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'speed',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      speedGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'speed',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      speedLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'speed',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      speedBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'speed',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      timestampEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'timestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      timestampGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'timestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      timestampLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'timestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      timestampBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'timestamp',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition> typeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'type',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      typeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'type',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      typeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'type',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition> typeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'type',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      typeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'type',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      typeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'type',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      typeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'type',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition> typeMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'type',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      typeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'type',
        value: '',
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      typeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'type',
        value: '',
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition> uuidEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'uuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      uuidGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'uuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      uuidLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'uuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition> uuidBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'uuid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      uuidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'uuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      uuidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'uuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      uuidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'uuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition> uuidMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'uuid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      uuidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'uuid',
        value: '',
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      uuidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'uuid',
        value: '',
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      voiceTextIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'voiceText',
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      voiceTextIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'voiceText',
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      voiceTextEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'voiceText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      voiceTextGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'voiceText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      voiceTextLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'voiceText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      voiceTextBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'voiceText',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      voiceTextStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'voiceText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      voiceTextEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'voiceText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      voiceTextContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'voiceText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      voiceTextMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'voiceText',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      voiceTextIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'voiceText',
        value: '',
      ));
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      voiceTextIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'voiceText',
        value: '',
      ));
    });
  }
}

extension RecordedEventQueryObject
    on QueryBuilder<RecordedEvent, RecordedEvent, QFilterCondition> {
  QueryBuilder<RecordedEvent, RecordedEvent, QAfterFilterCondition>
      sensorDataElement(FilterQuery<SensorPointEmbedded> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'sensorData');
    });
  }
}

extension RecordedEventQueryLinks
    on QueryBuilder<RecordedEvent, RecordedEvent, QFilterCondition> {}

extension RecordedEventQuerySortBy
    on QueryBuilder<RecordedEvent, RecordedEvent, QSortBy> {
  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy> sortByGForce() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'gForce', Sort.asc);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy> sortByGForceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'gForce', Sort.desc);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy> sortByLat() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lat', Sort.asc);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy> sortByLatDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lat', Sort.desc);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy> sortByLng() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lng', Sort.asc);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy> sortByLngDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lng', Sort.desc);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy> sortByNotes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.asc);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy> sortByNotesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.desc);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy> sortBySource() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'source', Sort.asc);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy> sortBySourceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'source', Sort.desc);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy> sortBySpeed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'speed', Sort.asc);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy> sortBySpeedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'speed', Sort.desc);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy> sortByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy>
      sortByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy> sortByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.asc);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy> sortByTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.desc);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy> sortByUuid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uuid', Sort.asc);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy> sortByUuidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uuid', Sort.desc);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy> sortByVoiceText() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'voiceText', Sort.asc);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy>
      sortByVoiceTextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'voiceText', Sort.desc);
    });
  }
}

extension RecordedEventQuerySortThenBy
    on QueryBuilder<RecordedEvent, RecordedEvent, QSortThenBy> {
  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy> thenByGForce() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'gForce', Sort.asc);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy> thenByGForceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'gForce', Sort.desc);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy> thenByLat() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lat', Sort.asc);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy> thenByLatDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lat', Sort.desc);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy> thenByLng() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lng', Sort.asc);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy> thenByLngDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lng', Sort.desc);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy> thenByNotes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.asc);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy> thenByNotesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.desc);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy> thenBySource() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'source', Sort.asc);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy> thenBySourceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'source', Sort.desc);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy> thenBySpeed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'speed', Sort.asc);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy> thenBySpeedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'speed', Sort.desc);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy> thenByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy>
      thenByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy> thenByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.asc);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy> thenByTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.desc);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy> thenByUuid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uuid', Sort.asc);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy> thenByUuidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uuid', Sort.desc);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy> thenByVoiceText() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'voiceText', Sort.asc);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QAfterSortBy>
      thenByVoiceTextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'voiceText', Sort.desc);
    });
  }
}

extension RecordedEventQueryWhereDistinct
    on QueryBuilder<RecordedEvent, RecordedEvent, QDistinct> {
  QueryBuilder<RecordedEvent, RecordedEvent, QDistinct> distinctByGForce() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'gForce');
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QDistinct> distinctByLat() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lat');
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QDistinct> distinctByLng() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lng');
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QDistinct> distinctByNotes(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'notes', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QDistinct> distinctBySource(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'source', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QDistinct> distinctBySpeed() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'speed');
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QDistinct> distinctByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'timestamp');
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QDistinct> distinctByType(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'type', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QDistinct> distinctByUuid(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'uuid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<RecordedEvent, RecordedEvent, QDistinct> distinctByVoiceText(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'voiceText', caseSensitive: caseSensitive);
    });
  }
}

extension RecordedEventQueryProperty
    on QueryBuilder<RecordedEvent, RecordedEvent, QQueryProperty> {
  QueryBuilder<RecordedEvent, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<RecordedEvent, double?, QQueryOperations> gForceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'gForce');
    });
  }

  QueryBuilder<RecordedEvent, double?, QQueryOperations> latProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lat');
    });
  }

  QueryBuilder<RecordedEvent, double?, QQueryOperations> lngProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lng');
    });
  }

  QueryBuilder<RecordedEvent, String?, QQueryOperations> notesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'notes');
    });
  }

  QueryBuilder<RecordedEvent, List<SensorPointEmbedded>, QQueryOperations>
      sensorDataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sensorData');
    });
  }

  QueryBuilder<RecordedEvent, String?, QQueryOperations> sourceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'source');
    });
  }

  QueryBuilder<RecordedEvent, double?, QQueryOperations> speedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'speed');
    });
  }

  QueryBuilder<RecordedEvent, DateTime, QQueryOperations> timestampProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'timestamp');
    });
  }

  QueryBuilder<RecordedEvent, String, QQueryOperations> typeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'type');
    });
  }

  QueryBuilder<RecordedEvent, String, QQueryOperations> uuidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'uuid');
    });
  }

  QueryBuilder<RecordedEvent, String?, QQueryOperations> voiceTextProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'voiceText');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetBrandCollection on Isar {
  IsarCollection<Brand> get brands => this.collection();
}

const BrandSchema = CollectionSchema(
  name: r'Brand',
  id: 4318366976370227238,
  properties: {
    r'cloudId': PropertySchema(
      id: 0,
      name: r'cloudId',
      type: IsarType.string,
    ),
    r'displayName': PropertySchema(
      id: 1,
      name: r'displayName',
      type: IsarType.string,
    ),
    r'isCustom': PropertySchema(
      id: 2,
      name: r'isCustom',
      type: IsarType.bool,
    ),
    r'isEnabled': PropertySchema(
      id: 3,
      name: r'isEnabled',
      type: IsarType.bool,
    ),
    r'logoUrl': PropertySchema(
      id: 4,
      name: r'logoUrl',
      type: IsarType.string,
    ),
    r'name': PropertySchema(
      id: 5,
      name: r'name',
      type: IsarType.string,
    ),
    r'order': PropertySchema(
      id: 6,
      name: r'order',
      type: IsarType.long,
    ),
    r'updatedAt': PropertySchema(
      id: 7,
      name: r'updatedAt',
      type: IsarType.dateTime,
    )
  },
  estimateSize: _brandEstimateSize,
  serialize: _brandSerialize,
  deserialize: _brandDeserialize,
  deserializeProp: _brandDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {
    r'versions': LinkSchema(
      id: 3260675837754504739,
      name: r'versions',
      target: r'SoftwareVersion',
      single: false,
    )
  },
  embeddedSchemas: {},
  getId: _brandGetId,
  getLinks: _brandGetLinks,
  attach: _brandAttach,
  version: '3.1.0+1',
);

int _brandEstimateSize(
  Brand object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.cloudId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.displayName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.logoUrl;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.name.length * 3;
  return bytesCount;
}

void _brandSerialize(
  Brand object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.cloudId);
  writer.writeString(offsets[1], object.displayName);
  writer.writeBool(offsets[2], object.isCustom);
  writer.writeBool(offsets[3], object.isEnabled);
  writer.writeString(offsets[4], object.logoUrl);
  writer.writeString(offsets[5], object.name);
  writer.writeLong(offsets[6], object.order);
  writer.writeDateTime(offsets[7], object.updatedAt);
}

Brand _brandDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Brand();
  object.cloudId = reader.readStringOrNull(offsets[0]);
  object.displayName = reader.readStringOrNull(offsets[1]);
  object.id = id;
  object.isCustom = reader.readBool(offsets[2]);
  object.isEnabled = reader.readBool(offsets[3]);
  object.logoUrl = reader.readStringOrNull(offsets[4]);
  object.name = reader.readString(offsets[5]);
  object.order = reader.readLong(offsets[6]);
  object.updatedAt = reader.readDateTimeOrNull(offsets[7]);
  return object;
}

P _brandDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readBool(offset)) as P;
    case 3:
      return (reader.readBool(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    case 7:
      return (reader.readDateTimeOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _brandGetId(Brand object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _brandGetLinks(Brand object) {
  return [object.versions];
}

void _brandAttach(IsarCollection<dynamic> col, Id id, Brand object) {
  object.id = id;
  object.versions
      .attach(col, col.isar.collection<SoftwareVersion>(), r'versions', id);
}

extension BrandQueryWhereSort on QueryBuilder<Brand, Brand, QWhere> {
  QueryBuilder<Brand, Brand, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension BrandQueryWhere on QueryBuilder<Brand, Brand, QWhereClause> {
  QueryBuilder<Brand, Brand, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<Brand, Brand, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<Brand, Brand, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<Brand, Brand, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension BrandQueryFilter on QueryBuilder<Brand, Brand, QFilterCondition> {
  QueryBuilder<Brand, Brand, QAfterFilterCondition> cloudIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'cloudId',
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> cloudIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'cloudId',
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> cloudIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cloudId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> cloudIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'cloudId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> cloudIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'cloudId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> cloudIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'cloudId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> cloudIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'cloudId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> cloudIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'cloudId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> cloudIdContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'cloudId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> cloudIdMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'cloudId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> cloudIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cloudId',
        value: '',
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> cloudIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'cloudId',
        value: '',
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> displayNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'displayName',
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> displayNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'displayName',
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> displayNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'displayName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> displayNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'displayName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> displayNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'displayName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> displayNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'displayName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> displayNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'displayName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> displayNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'displayName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> displayNameContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'displayName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> displayNameMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'displayName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> displayNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'displayName',
        value: '',
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> displayNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'displayName',
        value: '',
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> isCustomEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isCustom',
        value: value,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> isEnabledEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isEnabled',
        value: value,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> logoUrlIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'logoUrl',
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> logoUrlIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'logoUrl',
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> logoUrlEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'logoUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> logoUrlGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'logoUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> logoUrlLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'logoUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> logoUrlBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'logoUrl',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> logoUrlStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'logoUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> logoUrlEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'logoUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> logoUrlContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'logoUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> logoUrlMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'logoUrl',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> logoUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'logoUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> logoUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'logoUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> nameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> nameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> nameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> nameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'name',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> nameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> nameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> nameContains(String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> nameMatches(String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'name',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> orderEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'order',
        value: value,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> orderGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'order',
        value: value,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> orderLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'order',
        value: value,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> orderBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'order',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> updatedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'updatedAt',
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> updatedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'updatedAt',
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> updatedAtEqualTo(
      DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> updatedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> updatedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> updatedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'updatedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension BrandQueryObject on QueryBuilder<Brand, Brand, QFilterCondition> {}

extension BrandQueryLinks on QueryBuilder<Brand, Brand, QFilterCondition> {
  QueryBuilder<Brand, Brand, QAfterFilterCondition> versions(
      FilterQuery<SoftwareVersion> q) {
    return QueryBuilder.apply(this, (query) {
      return query.link(q, r'versions');
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> versionsLengthEqualTo(
      int length) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'versions', length, true, length, true);
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> versionsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'versions', 0, true, 0, true);
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> versionsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'versions', 0, false, 999999, true);
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> versionsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'versions', 0, true, length, include);
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> versionsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'versions', length, include, 999999, true);
    });
  }

  QueryBuilder<Brand, Brand, QAfterFilterCondition> versionsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(
          r'versions', lower, includeLower, upper, includeUpper);
    });
  }
}

extension BrandQuerySortBy on QueryBuilder<Brand, Brand, QSortBy> {
  QueryBuilder<Brand, Brand, QAfterSortBy> sortByCloudId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cloudId', Sort.asc);
    });
  }

  QueryBuilder<Brand, Brand, QAfterSortBy> sortByCloudIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cloudId', Sort.desc);
    });
  }

  QueryBuilder<Brand, Brand, QAfterSortBy> sortByDisplayName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayName', Sort.asc);
    });
  }

  QueryBuilder<Brand, Brand, QAfterSortBy> sortByDisplayNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayName', Sort.desc);
    });
  }

  QueryBuilder<Brand, Brand, QAfterSortBy> sortByIsCustom() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isCustom', Sort.asc);
    });
  }

  QueryBuilder<Brand, Brand, QAfterSortBy> sortByIsCustomDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isCustom', Sort.desc);
    });
  }

  QueryBuilder<Brand, Brand, QAfterSortBy> sortByIsEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isEnabled', Sort.asc);
    });
  }

  QueryBuilder<Brand, Brand, QAfterSortBy> sortByIsEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isEnabled', Sort.desc);
    });
  }

  QueryBuilder<Brand, Brand, QAfterSortBy> sortByLogoUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'logoUrl', Sort.asc);
    });
  }

  QueryBuilder<Brand, Brand, QAfterSortBy> sortByLogoUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'logoUrl', Sort.desc);
    });
  }

  QueryBuilder<Brand, Brand, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<Brand, Brand, QAfterSortBy> sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<Brand, Brand, QAfterSortBy> sortByOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'order', Sort.asc);
    });
  }

  QueryBuilder<Brand, Brand, QAfterSortBy> sortByOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'order', Sort.desc);
    });
  }

  QueryBuilder<Brand, Brand, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<Brand, Brand, QAfterSortBy> sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension BrandQuerySortThenBy on QueryBuilder<Brand, Brand, QSortThenBy> {
  QueryBuilder<Brand, Brand, QAfterSortBy> thenByCloudId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cloudId', Sort.asc);
    });
  }

  QueryBuilder<Brand, Brand, QAfterSortBy> thenByCloudIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cloudId', Sort.desc);
    });
  }

  QueryBuilder<Brand, Brand, QAfterSortBy> thenByDisplayName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayName', Sort.asc);
    });
  }

  QueryBuilder<Brand, Brand, QAfterSortBy> thenByDisplayNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayName', Sort.desc);
    });
  }

  QueryBuilder<Brand, Brand, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Brand, Brand, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Brand, Brand, QAfterSortBy> thenByIsCustom() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isCustom', Sort.asc);
    });
  }

  QueryBuilder<Brand, Brand, QAfterSortBy> thenByIsCustomDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isCustom', Sort.desc);
    });
  }

  QueryBuilder<Brand, Brand, QAfterSortBy> thenByIsEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isEnabled', Sort.asc);
    });
  }

  QueryBuilder<Brand, Brand, QAfterSortBy> thenByIsEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isEnabled', Sort.desc);
    });
  }

  QueryBuilder<Brand, Brand, QAfterSortBy> thenByLogoUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'logoUrl', Sort.asc);
    });
  }

  QueryBuilder<Brand, Brand, QAfterSortBy> thenByLogoUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'logoUrl', Sort.desc);
    });
  }

  QueryBuilder<Brand, Brand, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<Brand, Brand, QAfterSortBy> thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<Brand, Brand, QAfterSortBy> thenByOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'order', Sort.asc);
    });
  }

  QueryBuilder<Brand, Brand, QAfterSortBy> thenByOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'order', Sort.desc);
    });
  }

  QueryBuilder<Brand, Brand, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<Brand, Brand, QAfterSortBy> thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension BrandQueryWhereDistinct on QueryBuilder<Brand, Brand, QDistinct> {
  QueryBuilder<Brand, Brand, QDistinct> distinctByCloudId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cloudId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Brand, Brand, QDistinct> distinctByDisplayName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'displayName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Brand, Brand, QDistinct> distinctByIsCustom() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isCustom');
    });
  }

  QueryBuilder<Brand, Brand, QDistinct> distinctByIsEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isEnabled');
    });
  }

  QueryBuilder<Brand, Brand, QDistinct> distinctByLogoUrl(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'logoUrl', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Brand, Brand, QDistinct> distinctByName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Brand, Brand, QDistinct> distinctByOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'order');
    });
  }

  QueryBuilder<Brand, Brand, QDistinct> distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }
}

extension BrandQueryProperty on QueryBuilder<Brand, Brand, QQueryProperty> {
  QueryBuilder<Brand, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Brand, String?, QQueryOperations> cloudIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cloudId');
    });
  }

  QueryBuilder<Brand, String?, QQueryOperations> displayNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'displayName');
    });
  }

  QueryBuilder<Brand, bool, QQueryOperations> isCustomProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isCustom');
    });
  }

  QueryBuilder<Brand, bool, QQueryOperations> isEnabledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isEnabled');
    });
  }

  QueryBuilder<Brand, String?, QQueryOperations> logoUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'logoUrl');
    });
  }

  QueryBuilder<Brand, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<Brand, int, QQueryOperations> orderProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'order');
    });
  }

  QueryBuilder<Brand, DateTime?, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSoftwareVersionCollection on Isar {
  IsarCollection<SoftwareVersion> get softwareVersions => this.collection();
}

const SoftwareVersionSchema = CollectionSchema(
  name: r'SoftwareVersion',
  id: -7963522245691611834,
  properties: {
    r'cloudId': PropertySchema(
      id: 0,
      name: r'cloudId',
      type: IsarType.string,
    ),
    r'isCustom': PropertySchema(
      id: 1,
      name: r'isCustom',
      type: IsarType.bool,
    ),
    r'isEnabled': PropertySchema(
      id: 2,
      name: r'isEnabled',
      type: IsarType.bool,
    ),
    r'versionString': PropertySchema(
      id: 3,
      name: r'versionString',
      type: IsarType.string,
    )
  },
  estimateSize: _softwareVersionEstimateSize,
  serialize: _softwareVersionSerialize,
  deserialize: _softwareVersionDeserialize,
  deserializeProp: _softwareVersionDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {
    r'brand': LinkSchema(
      id: 8036301206253249206,
      name: r'brand',
      target: r'Brand',
      single: true,
    )
  },
  embeddedSchemas: {},
  getId: _softwareVersionGetId,
  getLinks: _softwareVersionGetLinks,
  attach: _softwareVersionAttach,
  version: '3.1.0+1',
);

int _softwareVersionEstimateSize(
  SoftwareVersion object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.cloudId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.versionString.length * 3;
  return bytesCount;
}

void _softwareVersionSerialize(
  SoftwareVersion object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.cloudId);
  writer.writeBool(offsets[1], object.isCustom);
  writer.writeBool(offsets[2], object.isEnabled);
  writer.writeString(offsets[3], object.versionString);
}

SoftwareVersion _softwareVersionDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SoftwareVersion();
  object.cloudId = reader.readStringOrNull(offsets[0]);
  object.id = id;
  object.isCustom = reader.readBool(offsets[1]);
  object.isEnabled = reader.readBool(offsets[2]);
  object.versionString = reader.readString(offsets[3]);
  return object;
}

P _softwareVersionDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readBool(offset)) as P;
    case 2:
      return (reader.readBool(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _softwareVersionGetId(SoftwareVersion object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _softwareVersionGetLinks(SoftwareVersion object) {
  return [object.brand];
}

void _softwareVersionAttach(
    IsarCollection<dynamic> col, Id id, SoftwareVersion object) {
  object.id = id;
  object.brand.attach(col, col.isar.collection<Brand>(), r'brand', id);
}

extension SoftwareVersionQueryWhereSort
    on QueryBuilder<SoftwareVersion, SoftwareVersion, QWhere> {
  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension SoftwareVersionQueryWhere
    on QueryBuilder<SoftwareVersion, SoftwareVersion, QWhereClause> {
  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterWhereClause>
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

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension SoftwareVersionQueryFilter
    on QueryBuilder<SoftwareVersion, SoftwareVersion, QFilterCondition> {
  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterFilterCondition>
      cloudIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'cloudId',
      ));
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterFilterCondition>
      cloudIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'cloudId',
      ));
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterFilterCondition>
      cloudIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cloudId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterFilterCondition>
      cloudIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'cloudId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterFilterCondition>
      cloudIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'cloudId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterFilterCondition>
      cloudIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'cloudId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterFilterCondition>
      cloudIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'cloudId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterFilterCondition>
      cloudIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'cloudId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterFilterCondition>
      cloudIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'cloudId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterFilterCondition>
      cloudIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'cloudId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterFilterCondition>
      cloudIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cloudId',
        value: '',
      ));
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterFilterCondition>
      cloudIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'cloudId',
        value: '',
      ));
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterFilterCondition>
      idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterFilterCondition>
      idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterFilterCondition>
      isCustomEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isCustom',
        value: value,
      ));
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterFilterCondition>
      isEnabledEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isEnabled',
        value: value,
      ));
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterFilterCondition>
      versionStringEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'versionString',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterFilterCondition>
      versionStringGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'versionString',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterFilterCondition>
      versionStringLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'versionString',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterFilterCondition>
      versionStringBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'versionString',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterFilterCondition>
      versionStringStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'versionString',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterFilterCondition>
      versionStringEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'versionString',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterFilterCondition>
      versionStringContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'versionString',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterFilterCondition>
      versionStringMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'versionString',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterFilterCondition>
      versionStringIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'versionString',
        value: '',
      ));
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterFilterCondition>
      versionStringIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'versionString',
        value: '',
      ));
    });
  }
}

extension SoftwareVersionQueryObject
    on QueryBuilder<SoftwareVersion, SoftwareVersion, QFilterCondition> {}

extension SoftwareVersionQueryLinks
    on QueryBuilder<SoftwareVersion, SoftwareVersion, QFilterCondition> {
  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterFilterCondition> brand(
      FilterQuery<Brand> q) {
    return QueryBuilder.apply(this, (query) {
      return query.link(q, r'brand');
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterFilterCondition>
      brandIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'brand', 0, true, 0, true);
    });
  }
}

extension SoftwareVersionQuerySortBy
    on QueryBuilder<SoftwareVersion, SoftwareVersion, QSortBy> {
  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterSortBy> sortByCloudId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cloudId', Sort.asc);
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterSortBy>
      sortByCloudIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cloudId', Sort.desc);
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterSortBy>
      sortByIsCustom() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isCustom', Sort.asc);
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterSortBy>
      sortByIsCustomDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isCustom', Sort.desc);
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterSortBy>
      sortByIsEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isEnabled', Sort.asc);
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterSortBy>
      sortByIsEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isEnabled', Sort.desc);
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterSortBy>
      sortByVersionString() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'versionString', Sort.asc);
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterSortBy>
      sortByVersionStringDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'versionString', Sort.desc);
    });
  }
}

extension SoftwareVersionQuerySortThenBy
    on QueryBuilder<SoftwareVersion, SoftwareVersion, QSortThenBy> {
  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterSortBy> thenByCloudId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cloudId', Sort.asc);
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterSortBy>
      thenByCloudIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cloudId', Sort.desc);
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterSortBy>
      thenByIsCustom() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isCustom', Sort.asc);
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterSortBy>
      thenByIsCustomDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isCustom', Sort.desc);
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterSortBy>
      thenByIsEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isEnabled', Sort.asc);
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterSortBy>
      thenByIsEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isEnabled', Sort.desc);
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterSortBy>
      thenByVersionString() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'versionString', Sort.asc);
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QAfterSortBy>
      thenByVersionStringDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'versionString', Sort.desc);
    });
  }
}

extension SoftwareVersionQueryWhereDistinct
    on QueryBuilder<SoftwareVersion, SoftwareVersion, QDistinct> {
  QueryBuilder<SoftwareVersion, SoftwareVersion, QDistinct> distinctByCloudId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cloudId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QDistinct>
      distinctByIsCustom() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isCustom');
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QDistinct>
      distinctByIsEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isEnabled');
    });
  }

  QueryBuilder<SoftwareVersion, SoftwareVersion, QDistinct>
      distinctByVersionString({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'versionString',
          caseSensitive: caseSensitive);
    });
  }
}

extension SoftwareVersionQueryProperty
    on QueryBuilder<SoftwareVersion, SoftwareVersion, QQueryProperty> {
  QueryBuilder<SoftwareVersion, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<SoftwareVersion, String?, QQueryOperations> cloudIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cloudId');
    });
  }

  QueryBuilder<SoftwareVersion, bool, QQueryOperations> isCustomProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isCustom');
    });
  }

  QueryBuilder<SoftwareVersion, bool, QQueryOperations> isEnabledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isEnabled');
    });
  }

  QueryBuilder<SoftwareVersion, String, QQueryOperations>
      versionStringProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'versionString');
    });
  }
}

// **************************************************************************
// IsarEmbeddedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

const SensorPointEmbeddedSchema = Schema(
  name: r'SensorPointEmbedded',
  id: 6642752412258630487,
  properties: {
    r'ax': PropertySchema(
      id: 0,
      name: r'ax',
      type: IsarType.double,
    ),
    r'ay': PropertySchema(
      id: 1,
      name: r'ay',
      type: IsarType.double,
    ),
    r'az': PropertySchema(
      id: 2,
      name: r'az',
      type: IsarType.double,
    ),
    r'gx': PropertySchema(
      id: 3,
      name: r'gx',
      type: IsarType.double,
    ),
    r'gy': PropertySchema(
      id: 4,
      name: r'gy',
      type: IsarType.double,
    ),
    r'gz': PropertySchema(
      id: 5,
      name: r'gz',
      type: IsarType.double,
    ),
    r'mx': PropertySchema(
      id: 6,
      name: r'mx',
      type: IsarType.double,
    ),
    r'my': PropertySchema(
      id: 7,
      name: r'my',
      type: IsarType.double,
    ),
    r'mz': PropertySchema(
      id: 8,
      name: r'mz',
      type: IsarType.double,
    ),
    r'offsetMs': PropertySchema(
      id: 9,
      name: r'offsetMs',
      type: IsarType.long,
    )
  },
  estimateSize: _sensorPointEmbeddedEstimateSize,
  serialize: _sensorPointEmbeddedSerialize,
  deserialize: _sensorPointEmbeddedDeserialize,
  deserializeProp: _sensorPointEmbeddedDeserializeProp,
);

int _sensorPointEmbeddedEstimateSize(
  SensorPointEmbedded object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  return bytesCount;
}

void _sensorPointEmbeddedSerialize(
  SensorPointEmbedded object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDouble(offsets[0], object.ax);
  writer.writeDouble(offsets[1], object.ay);
  writer.writeDouble(offsets[2], object.az);
  writer.writeDouble(offsets[3], object.gx);
  writer.writeDouble(offsets[4], object.gy);
  writer.writeDouble(offsets[5], object.gz);
  writer.writeDouble(offsets[6], object.mx);
  writer.writeDouble(offsets[7], object.my);
  writer.writeDouble(offsets[8], object.mz);
  writer.writeLong(offsets[9], object.offsetMs);
}

SensorPointEmbedded _sensorPointEmbeddedDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SensorPointEmbedded();
  object.ax = reader.readDoubleOrNull(offsets[0]);
  object.ay = reader.readDoubleOrNull(offsets[1]);
  object.az = reader.readDoubleOrNull(offsets[2]);
  object.gx = reader.readDoubleOrNull(offsets[3]);
  object.gy = reader.readDoubleOrNull(offsets[4]);
  object.gz = reader.readDoubleOrNull(offsets[5]);
  object.mx = reader.readDoubleOrNull(offsets[6]);
  object.my = reader.readDoubleOrNull(offsets[7]);
  object.mz = reader.readDoubleOrNull(offsets[8]);
  object.offsetMs = reader.readLongOrNull(offsets[9]);
  return object;
}

P _sensorPointEmbeddedDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDoubleOrNull(offset)) as P;
    case 1:
      return (reader.readDoubleOrNull(offset)) as P;
    case 2:
      return (reader.readDoubleOrNull(offset)) as P;
    case 3:
      return (reader.readDoubleOrNull(offset)) as P;
    case 4:
      return (reader.readDoubleOrNull(offset)) as P;
    case 5:
      return (reader.readDoubleOrNull(offset)) as P;
    case 6:
      return (reader.readDoubleOrNull(offset)) as P;
    case 7:
      return (reader.readDoubleOrNull(offset)) as P;
    case 8:
      return (reader.readDoubleOrNull(offset)) as P;
    case 9:
      return (reader.readLongOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

extension SensorPointEmbeddedQueryFilter on QueryBuilder<SensorPointEmbedded,
    SensorPointEmbedded, QFilterCondition> {
  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      axIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'ax',
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      axIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'ax',
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      axEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ax',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      axGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'ax',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      axLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'ax',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      axBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'ax',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      ayIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'ay',
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      ayIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'ay',
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      ayEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ay',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      ayGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'ay',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      ayLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'ay',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      ayBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'ay',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      azIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'az',
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      azIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'az',
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      azEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'az',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      azGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'az',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      azLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'az',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      azBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'az',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      gxIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'gx',
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      gxIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'gx',
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      gxEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'gx',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      gxGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'gx',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      gxLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'gx',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      gxBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'gx',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      gyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'gy',
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      gyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'gy',
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      gyEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'gy',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      gyGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'gy',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      gyLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'gy',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      gyBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'gy',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      gzIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'gz',
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      gzIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'gz',
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      gzEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'gz',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      gzGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'gz',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      gzLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'gz',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      gzBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'gz',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      mxIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'mx',
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      mxIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'mx',
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      mxEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'mx',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      mxGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'mx',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      mxLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'mx',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      mxBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'mx',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      myIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'my',
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      myIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'my',
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      myEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'my',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      myGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'my',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      myLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'my',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      myBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'my',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      mzIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'mz',
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      mzIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'mz',
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      mzEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'mz',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      mzGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'mz',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      mzLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'mz',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      mzBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'mz',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      offsetMsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'offsetMs',
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      offsetMsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'offsetMs',
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      offsetMsEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'offsetMs',
        value: value,
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      offsetMsGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'offsetMs',
        value: value,
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      offsetMsLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'offsetMs',
        value: value,
      ));
    });
  }

  QueryBuilder<SensorPointEmbedded, SensorPointEmbedded, QAfterFilterCondition>
      offsetMsBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'offsetMs',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension SensorPointEmbeddedQueryObject on QueryBuilder<SensorPointEmbedded,
    SensorPointEmbedded, QFilterCondition> {}
