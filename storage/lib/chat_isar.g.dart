// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_isar.dart';

// ignore_for_file: experimental_member_use

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetChatConversationEntityCollection on Isar {
  IsarCollection<ChatConversationEntity> get chatConversationEntitys =>
      this.collection();
}

const ChatConversationEntitySchema = CollectionSchema(
  name: r'conversation',
  id: 407682453440200747,
  properties: {
    r'account_id': PropertySchema(
      id: 0,
      name: r'account_id',
      type: IsarType.string,
    ),
    r'bind_rev': PropertySchema(id: 1, name: r'bind_rev', type: IsarType.long),
    r'conversation_id': PropertySchema(
      id: 2,
      name: r'conversation_id',
      type: IsarType.string,
    ),
    r'delivery_state': PropertySchema(
      id: 3,
      name: r'delivery_state',
      type: IsarType.string,
    ),
    r'kind': PropertySchema(id: 4, name: r'kind', type: IsarType.string),
    r'owner_id': PropertySchema(
      id: 5,
      name: r'owner_id',
      type: IsarType.string,
    ),
    r'peer_id': PropertySchema(id: 6, name: r'peer_id', type: IsarType.string),
    r'summary': PropertySchema(id: 7, name: r'summary', type: IsarType.string),
    r'title': PropertySchema(id: 8, name: r'title', type: IsarType.string),
    r'unread_count': PropertySchema(
      id: 9,
      name: r'unread_count',
      type: IsarType.long,
    ),
    r'updated_at': PropertySchema(
      id: 10,
      name: r'updated_at',
      type: IsarType.long,
    ),
  },

  estimateSize: _chatConversationEntityEstimateSize,
  serialize: _chatConversationEntitySerialize,
  deserialize: _chatConversationEntityDeserialize,
  deserializeProp: _chatConversationEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'owner_id_conversation_id': IndexSchema(
      id: 55240996454853881,
      name: r'owner_id_conversation_id',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'owner_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'conversation_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'peer_id': IndexSchema(
      id: -1524088446866973519,
      name: r'peer_id',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'peer_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'updated_at': IndexSchema(
      id: -1449665799000962892,
      name: r'updated_at',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'updated_at',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _chatConversationEntityGetId,
  getLinks: _chatConversationEntityGetLinks,
  attach: _chatConversationEntityAttach,
  version: '3.3.2',
);

int _chatConversationEntityEstimateSize(
  ChatConversationEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.accountId.length * 3;
  bytesCount += 3 + object.conversationId.length * 3;
  bytesCount += 3 + object.lastDeliveryState.length * 3;
  {
    final value = object.conversationKind;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.ownerUserId.length * 3;
  bytesCount += 3 + object.peerUserId.length * 3;
  bytesCount += 3 + object.lastMessageSummary.length * 3;
  {
    final value = object.title;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _chatConversationEntitySerialize(
  ChatConversationEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.accountId);
  writer.writeLong(offsets[1], object.bindingRevision);
  writer.writeString(offsets[2], object.conversationId);
  writer.writeString(offsets[3], object.lastDeliveryState);
  writer.writeString(offsets[4], object.conversationKind);
  writer.writeString(offsets[5], object.ownerUserId);
  writer.writeString(offsets[6], object.peerUserId);
  writer.writeString(offsets[7], object.lastMessageSummary);
  writer.writeString(offsets[8], object.title);
  writer.writeLong(offsets[9], object.unreadCount);
  writer.writeLong(offsets[10], object.updatedAtMillis);
}

ChatConversationEntity _chatConversationEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ChatConversationEntity();
  object.accountId = reader.readString(offsets[0]);
  object.bindingRevision = reader.readLong(offsets[1]);
  object.conversationId = reader.readString(offsets[2]);
  object.lastDeliveryState = reader.readString(offsets[3]);
  object.id = id;
  object.conversationKind = reader.readStringOrNull(offsets[4]);
  object.ownerUserId = reader.readString(offsets[5]);
  object.peerUserId = reader.readString(offsets[6]);
  object.lastMessageSummary = reader.readString(offsets[7]);
  object.title = reader.readStringOrNull(offsets[8]);
  object.unreadCount = reader.readLong(offsets[9]);
  object.updatedAtMillis = reader.readLong(offsets[10]);
  return object;
}

P _chatConversationEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readLong(offset)) as P;
    case 10:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _chatConversationEntityGetId(ChatConversationEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _chatConversationEntityGetLinks(
  ChatConversationEntity object,
) {
  return [];
}

void _chatConversationEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  ChatConversationEntity object,
) {
  object.id = id;
}

extension ChatConversationEntityByIndex
    on IsarCollection<ChatConversationEntity> {
  Future<ChatConversationEntity?> getByOwnerUserIdConversationId(
    String ownerUserId,
    String conversationId,
  ) {
    return getByIndex(r'owner_id_conversation_id', [
      ownerUserId,
      conversationId,
    ]);
  }

  ChatConversationEntity? getByOwnerUserIdConversationIdSync(
    String ownerUserId,
    String conversationId,
  ) {
    return getByIndexSync(r'owner_id_conversation_id', [
      ownerUserId,
      conversationId,
    ]);
  }

  Future<bool> deleteByOwnerUserIdConversationId(
    String ownerUserId,
    String conversationId,
  ) {
    return deleteByIndex(r'owner_id_conversation_id', [
      ownerUserId,
      conversationId,
    ]);
  }

  bool deleteByOwnerUserIdConversationIdSync(
    String ownerUserId,
    String conversationId,
  ) {
    return deleteByIndexSync(r'owner_id_conversation_id', [
      ownerUserId,
      conversationId,
    ]);
  }

  Future<List<ChatConversationEntity?>> getAllByOwnerUserIdConversationId(
    List<String> ownerUserIdValues,
    List<String> conversationIdValues,
  ) {
    final len = ownerUserIdValues.length;
    assert(
      conversationIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerUserIdValues[i], conversationIdValues[i]]);
    }

    return getAllByIndex(r'owner_id_conversation_id', values);
  }

  List<ChatConversationEntity?> getAllByOwnerUserIdConversationIdSync(
    List<String> ownerUserIdValues,
    List<String> conversationIdValues,
  ) {
    final len = ownerUserIdValues.length;
    assert(
      conversationIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerUserIdValues[i], conversationIdValues[i]]);
    }

    return getAllByIndexSync(r'owner_id_conversation_id', values);
  }

  Future<int> deleteAllByOwnerUserIdConversationId(
    List<String> ownerUserIdValues,
    List<String> conversationIdValues,
  ) {
    final len = ownerUserIdValues.length;
    assert(
      conversationIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerUserIdValues[i], conversationIdValues[i]]);
    }

    return deleteAllByIndex(r'owner_id_conversation_id', values);
  }

  int deleteAllByOwnerUserIdConversationIdSync(
    List<String> ownerUserIdValues,
    List<String> conversationIdValues,
  ) {
    final len = ownerUserIdValues.length;
    assert(
      conversationIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerUserIdValues[i], conversationIdValues[i]]);
    }

    return deleteAllByIndexSync(r'owner_id_conversation_id', values);
  }

  Future<Id> putByOwnerUserIdConversationId(ChatConversationEntity object) {
    return putByIndex(r'owner_id_conversation_id', object);
  }

  Id putByOwnerUserIdConversationIdSync(
    ChatConversationEntity object, {
    bool saveLinks = true,
  }) {
    return putByIndexSync(
      r'owner_id_conversation_id',
      object,
      saveLinks: saveLinks,
    );
  }

  Future<List<Id>> putAllByOwnerUserIdConversationId(
    List<ChatConversationEntity> objects,
  ) {
    return putAllByIndex(r'owner_id_conversation_id', objects);
  }

  List<Id> putAllByOwnerUserIdConversationIdSync(
    List<ChatConversationEntity> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(
      r'owner_id_conversation_id',
      objects,
      saveLinks: saveLinks,
    );
  }
}

extension ChatConversationEntityQueryWhereSort
    on QueryBuilder<ChatConversationEntity, ChatConversationEntity, QWhere> {
  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterWhere>
  anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterWhere>
  anyUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'updated_at'),
      );
    });
  }
}

extension ChatConversationEntityQueryWhere
    on
        QueryBuilder<
          ChatConversationEntity,
          ChatConversationEntity,
          QWhereClause
        > {
  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterWhereClause
  >
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterWhereClause
  >
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

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterWhereClause
  >
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterWhereClause
  >
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterWhereClause
  >
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

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterWhereClause
  >
  ownerUserIdEqualToAnyConversationId(String ownerUserId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'owner_id_conversation_id',
          value: [ownerUserId],
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterWhereClause
  >
  ownerUserIdNotEqualToAnyConversationId(String ownerUserId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_conversation_id',
                lower: [],
                upper: [ownerUserId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_conversation_id',
                lower: [ownerUserId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_conversation_id',
                lower: [ownerUserId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_conversation_id',
                lower: [],
                upper: [ownerUserId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterWhereClause
  >
  ownerUserIdConversationIdEqualTo(String ownerUserId, String conversationId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'owner_id_conversation_id',
          value: [ownerUserId, conversationId],
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterWhereClause
  >
  ownerUserIdEqualToConversationIdNotEqualTo(
    String ownerUserId,
    String conversationId,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_conversation_id',
                lower: [ownerUserId],
                upper: [ownerUserId, conversationId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_conversation_id',
                lower: [ownerUserId, conversationId],
                includeLower: false,
                upper: [ownerUserId],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_conversation_id',
                lower: [ownerUserId, conversationId],
                includeLower: false,
                upper: [ownerUserId],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_conversation_id',
                lower: [ownerUserId],
                upper: [ownerUserId, conversationId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterWhereClause
  >
  peerUserIdEqualTo(String peerUserId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'peer_id', value: [peerUserId]),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterWhereClause
  >
  peerUserIdNotEqualTo(String peerUserId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'peer_id',
                lower: [],
                upper: [peerUserId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'peer_id',
                lower: [peerUserId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'peer_id',
                lower: [peerUserId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'peer_id',
                lower: [],
                upper: [peerUserId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterWhereClause
  >
  updatedAtMillisEqualTo(int updatedAtMillis) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'updated_at',
          value: [updatedAtMillis],
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterWhereClause
  >
  updatedAtMillisNotEqualTo(int updatedAtMillis) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'updated_at',
                lower: [],
                upper: [updatedAtMillis],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'updated_at',
                lower: [updatedAtMillis],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'updated_at',
                lower: [updatedAtMillis],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'updated_at',
                lower: [],
                upper: [updatedAtMillis],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterWhereClause
  >
  updatedAtMillisGreaterThan(int updatedAtMillis, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'updated_at',
          lower: [updatedAtMillis],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterWhereClause
  >
  updatedAtMillisLessThan(int updatedAtMillis, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'updated_at',
          lower: [],
          upper: [updatedAtMillis],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterWhereClause
  >
  updatedAtMillisBetween(
    int lowerUpdatedAtMillis,
    int upperUpdatedAtMillis, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'updated_at',
          lower: [lowerUpdatedAtMillis],
          includeLower: includeLower,
          upper: [upperUpdatedAtMillis],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension ChatConversationEntityQueryFilter
    on
        QueryBuilder<
          ChatConversationEntity,
          ChatConversationEntity,
          QFilterCondition
        > {
  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  accountIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  accountIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  accountIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  accountIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'account_id',
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
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  accountIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  accountIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  accountIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  accountIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'account_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  accountIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'account_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  accountIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'account_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  bindingRevisionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'bind_rev', value: value),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  bindingRevisionGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'bind_rev',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  bindingRevisionLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'bind_rev',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  bindingRevisionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'bind_rev',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  conversationIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'conversation_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  conversationIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'conversation_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  conversationIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'conversation_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  conversationIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'conversation_id',
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
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  conversationIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'conversation_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  conversationIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'conversation_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  conversationIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'conversation_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  conversationIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'conversation_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  conversationIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'conversation_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  conversationIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'conversation_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  lastDeliveryStateEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'delivery_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  lastDeliveryStateGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'delivery_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  lastDeliveryStateLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'delivery_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  lastDeliveryStateBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'delivery_state',
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
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  lastDeliveryStateStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'delivery_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  lastDeliveryStateEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'delivery_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  lastDeliveryStateContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'delivery_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  lastDeliveryStateMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'delivery_state',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  lastDeliveryStateIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'delivery_state', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  lastDeliveryStateIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'delivery_state', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
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
    ChatConversationEntity,
    ChatConversationEntity,
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
    ChatConversationEntity,
    ChatConversationEntity,
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
    ChatConversationEntity,
    ChatConversationEntity,
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
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  conversationKindIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'kind'),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  conversationKindIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'kind'),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  conversationKindEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  conversationKindGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  conversationKindLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  conversationKindBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'kind',
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
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  conversationKindStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  conversationKindEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  conversationKindContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  conversationKindMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'kind',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  conversationKindIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'kind', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  conversationKindIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'kind', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  ownerUserIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  ownerUserIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  ownerUserIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  ownerUserIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'owner_id',
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
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  ownerUserIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  ownerUserIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  ownerUserIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  ownerUserIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'owner_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  ownerUserIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'owner_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  ownerUserIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'owner_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  peerUserIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'peer_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  peerUserIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'peer_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  peerUserIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'peer_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  peerUserIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'peer_id',
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
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  peerUserIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'peer_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  peerUserIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'peer_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  peerUserIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'peer_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  peerUserIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'peer_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  peerUserIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'peer_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  peerUserIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'peer_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  lastMessageSummaryEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'summary',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  lastMessageSummaryGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'summary',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  lastMessageSummaryLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'summary',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  lastMessageSummaryBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'summary',
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
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  lastMessageSummaryStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'summary',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  lastMessageSummaryEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'summary',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  lastMessageSummaryContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'summary',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  lastMessageSummaryMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'summary',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  lastMessageSummaryIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'summary', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  lastMessageSummaryIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'summary', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  titleIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'title'),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  titleIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'title'),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  titleEqualTo(String? value, {bool caseSensitive = true}) {
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
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  titleGreaterThan(
    String? value, {
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
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  titleLessThan(
    String? value, {
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
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  titleBetween(
    String? lower,
    String? upper, {
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
    ChatConversationEntity,
    ChatConversationEntity,
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
    ChatConversationEntity,
    ChatConversationEntity,
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
    ChatConversationEntity,
    ChatConversationEntity,
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
    ChatConversationEntity,
    ChatConversationEntity,
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
    ChatConversationEntity,
    ChatConversationEntity,
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
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'title', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  unreadCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'unread_count', value: value),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  unreadCountGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'unread_count',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  unreadCountLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'unread_count',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  unreadCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'unread_count',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  updatedAtMillisEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'updated_at', value: value),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  updatedAtMillisGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'updated_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  updatedAtMillisLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'updated_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ChatConversationEntity,
    ChatConversationEntity,
    QAfterFilterCondition
  >
  updatedAtMillisBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'updated_at',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension ChatConversationEntityQueryObject
    on
        QueryBuilder<
          ChatConversationEntity,
          ChatConversationEntity,
          QFilterCondition
        > {}

extension ChatConversationEntityQueryLinks
    on
        QueryBuilder<
          ChatConversationEntity,
          ChatConversationEntity,
          QFilterCondition
        > {}

extension ChatConversationEntityQuerySortBy
    on QueryBuilder<ChatConversationEntity, ChatConversationEntity, QSortBy> {
  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  sortByAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  sortByAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  sortByBindingRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bind_rev', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  sortByBindingRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bind_rev', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  sortByConversationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversation_id', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  sortByConversationIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversation_id', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  sortByLastDeliveryState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'delivery_state', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  sortByLastDeliveryStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'delivery_state', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  sortByConversationKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  sortByConversationKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  sortByOwnerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'owner_id', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  sortByOwnerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'owner_id', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  sortByPeerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'peer_id', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  sortByPeerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'peer_id', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  sortByLastMessageSummary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'summary', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  sortByLastMessageSummaryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'summary', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  sortByUnreadCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unread_count', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  sortByUnreadCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unread_count', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  sortByUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updated_at', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  sortByUpdatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updated_at', Sort.desc);
    });
  }
}

extension ChatConversationEntityQuerySortThenBy
    on
        QueryBuilder<
          ChatConversationEntity,
          ChatConversationEntity,
          QSortThenBy
        > {
  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  thenByAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  thenByAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  thenByBindingRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bind_rev', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  thenByBindingRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bind_rev', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  thenByConversationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversation_id', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  thenByConversationIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversation_id', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  thenByLastDeliveryState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'delivery_state', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  thenByLastDeliveryStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'delivery_state', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  thenByConversationKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  thenByConversationKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  thenByOwnerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'owner_id', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  thenByOwnerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'owner_id', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  thenByPeerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'peer_id', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  thenByPeerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'peer_id', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  thenByLastMessageSummary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'summary', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  thenByLastMessageSummaryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'summary', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  thenByUnreadCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unread_count', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  thenByUnreadCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unread_count', Sort.desc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  thenByUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updated_at', Sort.asc);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QAfterSortBy>
  thenByUpdatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updated_at', Sort.desc);
    });
  }
}

extension ChatConversationEntityQueryWhereDistinct
    on QueryBuilder<ChatConversationEntity, ChatConversationEntity, QDistinct> {
  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QDistinct>
  distinctByAccountId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'account_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QDistinct>
  distinctByBindingRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'bind_rev');
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QDistinct>
  distinctByConversationId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'conversation_id',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QDistinct>
  distinctByLastDeliveryState({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'delivery_state',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QDistinct>
  distinctByConversationKind({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'kind', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QDistinct>
  distinctByOwnerUserId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'owner_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QDistinct>
  distinctByPeerUserId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'peer_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QDistinct>
  distinctByLastMessageSummary({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'summary', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QDistinct>
  distinctByTitle({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QDistinct>
  distinctByUnreadCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'unread_count');
    });
  }

  QueryBuilder<ChatConversationEntity, ChatConversationEntity, QDistinct>
  distinctByUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updated_at');
    });
  }
}

extension ChatConversationEntityQueryProperty
    on
        QueryBuilder<
          ChatConversationEntity,
          ChatConversationEntity,
          QQueryProperty
        > {
  QueryBuilder<ChatConversationEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ChatConversationEntity, String, QQueryOperations>
  accountIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'account_id');
    });
  }

  QueryBuilder<ChatConversationEntity, int, QQueryOperations>
  bindingRevisionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'bind_rev');
    });
  }

  QueryBuilder<ChatConversationEntity, String, QQueryOperations>
  conversationIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'conversation_id');
    });
  }

  QueryBuilder<ChatConversationEntity, String, QQueryOperations>
  lastDeliveryStateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'delivery_state');
    });
  }

  QueryBuilder<ChatConversationEntity, String?, QQueryOperations>
  conversationKindProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'kind');
    });
  }

  QueryBuilder<ChatConversationEntity, String, QQueryOperations>
  ownerUserIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'owner_id');
    });
  }

  QueryBuilder<ChatConversationEntity, String, QQueryOperations>
  peerUserIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'peer_id');
    });
  }

  QueryBuilder<ChatConversationEntity, String, QQueryOperations>
  lastMessageSummaryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'summary');
    });
  }

  QueryBuilder<ChatConversationEntity, String?, QQueryOperations>
  titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }

  QueryBuilder<ChatConversationEntity, int, QQueryOperations>
  unreadCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'unread_count');
    });
  }

  QueryBuilder<ChatConversationEntity, int, QQueryOperations>
  updatedAtMillisProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updated_at');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetChatMessageEntityCollection on Isar {
  IsarCollection<ChatMessageEntity> get chatMessageEntitys => this.collection();
}

const ChatMessageEntitySchema = CollectionSchema(
  name: r'message',
  id: 800701444045231354,
  properties: {
    r'account_id': PropertySchema(
      id: 0,
      name: r'account_id',
      type: IsarType.string,
    ),
    r'bind_rev': PropertySchema(id: 1, name: r'bind_rev', type: IsarType.long),
    r'conversation_id': PropertySchema(
      id: 2,
      name: r'conversation_id',
      type: IsarType.string,
    ),
    r'created_at': PropertySchema(
      id: 3,
      name: r'created_at',
      type: IsarType.long,
    ),
    r'delivery_state': PropertySchema(
      id: 4,
      name: r'delivery_state',
      type: IsarType.string,
    ),
    r'direction': PropertySchema(
      id: 5,
      name: r'direction',
      type: IsarType.string,
    ),
    r'kind': PropertySchema(id: 6, name: r'kind', type: IsarType.string),
    r'message_bytes': PropertySchema(
      id: 7,
      name: r'message_bytes',
      type: IsarType.string,
    ),
    r'message_id': PropertySchema(
      id: 8,
      name: r'message_id',
      type: IsarType.string,
    ),
    r'owner_id': PropertySchema(
      id: 9,
      name: r'owner_id',
      type: IsarType.string,
    ),
    r'payload_json': PropertySchema(
      id: 10,
      name: r'payload_json',
      type: IsarType.string,
    ),
    r'recipient_id': PropertySchema(
      id: 11,
      name: r'recipient_id',
      type: IsarType.string,
    ),
    r'search_tokens': PropertySchema(
      id: 12,
      name: r'search_tokens',
      type: IsarType.stringList,
    ),
    r'sender_id': PropertySchema(
      id: 13,
      name: r'sender_id',
      type: IsarType.string,
    ),
  },

  estimateSize: _chatMessageEntityEstimateSize,
  serialize: _chatMessageEntitySerialize,
  deserialize: _chatMessageEntityDeserialize,
  deserializeProp: _chatMessageEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'owner_id_message_id': IndexSchema(
      id: -5137609912169235308,
      name: r'owner_id_message_id',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'owner_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'message_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'conversation_id': IndexSchema(
      id: -4048954474591270722,
      name: r'conversation_id',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'conversation_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'search_tokens': IndexSchema(
      id: 1806093144852795780,
      name: r'search_tokens',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'search_tokens',
          type: IndexType.value,
          caseSensitive: true,
        ),
      ],
    ),
    r'created_at': IndexSchema(
      id: 6296488693525790031,
      name: r'created_at',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'created_at',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _chatMessageEntityGetId,
  getLinks: _chatMessageEntityGetLinks,
  attach: _chatMessageEntityAttach,
  version: '3.3.2',
);

int _chatMessageEntityEstimateSize(
  ChatMessageEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.accountId.length * 3;
  bytesCount += 3 + object.conversationId.length * 3;
  bytesCount += 3 + object.deliveryState.length * 3;
  bytesCount += 3 + object.direction.length * 3;
  bytesCount += 3 + object.messageKind.length * 3;
  bytesCount += 3 + object.messageBytesHex.length * 3;
  bytesCount += 3 + object.messageId.length * 3;
  bytesCount += 3 + object.ownerUserId.length * 3;
  {
    final value = object.payloadJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.recipientUserId.length * 3;
  bytesCount += 3 + object.searchTokens.length * 3;
  {
    for (var i = 0; i < object.searchTokens.length; i++) {
      final value = object.searchTokens[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.senderUserId.length * 3;
  return bytesCount;
}

void _chatMessageEntitySerialize(
  ChatMessageEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.accountId);
  writer.writeLong(offsets[1], object.bindingRevision);
  writer.writeString(offsets[2], object.conversationId);
  writer.writeLong(offsets[3], object.createdAtMillis);
  writer.writeString(offsets[4], object.deliveryState);
  writer.writeString(offsets[5], object.direction);
  writer.writeString(offsets[6], object.messageKind);
  writer.writeString(offsets[7], object.messageBytesHex);
  writer.writeString(offsets[8], object.messageId);
  writer.writeString(offsets[9], object.ownerUserId);
  writer.writeString(offsets[10], object.payloadJson);
  writer.writeString(offsets[11], object.recipientUserId);
  writer.writeStringList(offsets[12], object.searchTokens);
  writer.writeString(offsets[13], object.senderUserId);
}

ChatMessageEntity _chatMessageEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ChatMessageEntity();
  object.accountId = reader.readString(offsets[0]);
  object.bindingRevision = reader.readLong(offsets[1]);
  object.conversationId = reader.readString(offsets[2]);
  object.createdAtMillis = reader.readLong(offsets[3]);
  object.deliveryState = reader.readString(offsets[4]);
  object.direction = reader.readString(offsets[5]);
  object.id = id;
  object.messageKind = reader.readString(offsets[6]);
  object.messageBytesHex = reader.readString(offsets[7]);
  object.messageId = reader.readString(offsets[8]);
  object.ownerUserId = reader.readString(offsets[9]);
  object.payloadJson = reader.readStringOrNull(offsets[10]);
  object.recipientUserId = reader.readString(offsets[11]);
  object.searchTokens = reader.readStringList(offsets[12]) ?? [];
  object.senderUserId = reader.readString(offsets[13]);
  return object;
}

P _chatMessageEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    case 10:
      return (reader.readStringOrNull(offset)) as P;
    case 11:
      return (reader.readString(offset)) as P;
    case 12:
      return (reader.readStringList(offset) ?? []) as P;
    case 13:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _chatMessageEntityGetId(ChatMessageEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _chatMessageEntityGetLinks(
  ChatMessageEntity object,
) {
  return [];
}

void _chatMessageEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  ChatMessageEntity object,
) {
  object.id = id;
}

extension ChatMessageEntityByIndex on IsarCollection<ChatMessageEntity> {
  Future<ChatMessageEntity?> getByOwnerUserIdMessageId(
    String ownerUserId,
    String messageId,
  ) {
    return getByIndex(r'owner_id_message_id', [ownerUserId, messageId]);
  }

  ChatMessageEntity? getByOwnerUserIdMessageIdSync(
    String ownerUserId,
    String messageId,
  ) {
    return getByIndexSync(r'owner_id_message_id', [ownerUserId, messageId]);
  }

  Future<bool> deleteByOwnerUserIdMessageId(
    String ownerUserId,
    String messageId,
  ) {
    return deleteByIndex(r'owner_id_message_id', [ownerUserId, messageId]);
  }

  bool deleteByOwnerUserIdMessageIdSync(String ownerUserId, String messageId) {
    return deleteByIndexSync(r'owner_id_message_id', [ownerUserId, messageId]);
  }

  Future<List<ChatMessageEntity?>> getAllByOwnerUserIdMessageId(
    List<String> ownerUserIdValues,
    List<String> messageIdValues,
  ) {
    final len = ownerUserIdValues.length;
    assert(
      messageIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerUserIdValues[i], messageIdValues[i]]);
    }

    return getAllByIndex(r'owner_id_message_id', values);
  }

  List<ChatMessageEntity?> getAllByOwnerUserIdMessageIdSync(
    List<String> ownerUserIdValues,
    List<String> messageIdValues,
  ) {
    final len = ownerUserIdValues.length;
    assert(
      messageIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerUserIdValues[i], messageIdValues[i]]);
    }

    return getAllByIndexSync(r'owner_id_message_id', values);
  }

  Future<int> deleteAllByOwnerUserIdMessageId(
    List<String> ownerUserIdValues,
    List<String> messageIdValues,
  ) {
    final len = ownerUserIdValues.length;
    assert(
      messageIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerUserIdValues[i], messageIdValues[i]]);
    }

    return deleteAllByIndex(r'owner_id_message_id', values);
  }

  int deleteAllByOwnerUserIdMessageIdSync(
    List<String> ownerUserIdValues,
    List<String> messageIdValues,
  ) {
    final len = ownerUserIdValues.length;
    assert(
      messageIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerUserIdValues[i], messageIdValues[i]]);
    }

    return deleteAllByIndexSync(r'owner_id_message_id', values);
  }

  Future<Id> putByOwnerUserIdMessageId(ChatMessageEntity object) {
    return putByIndex(r'owner_id_message_id', object);
  }

  Id putByOwnerUserIdMessageIdSync(
    ChatMessageEntity object, {
    bool saveLinks = true,
  }) {
    return putByIndexSync(r'owner_id_message_id', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByOwnerUserIdMessageId(
    List<ChatMessageEntity> objects,
  ) {
    return putAllByIndex(r'owner_id_message_id', objects);
  }

  List<Id> putAllByOwnerUserIdMessageIdSync(
    List<ChatMessageEntity> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(
      r'owner_id_message_id',
      objects,
      saveLinks: saveLinks,
    );
  }
}

extension ChatMessageEntityQueryWhereSort
    on QueryBuilder<ChatMessageEntity, ChatMessageEntity, QWhere> {
  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhere>
  anySearchTokensElement() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'search_tokens'),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhere>
  anyCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'created_at'),
      );
    });
  }
}

extension ChatMessageEntityQueryWhere
    on QueryBuilder<ChatMessageEntity, ChatMessageEntity, QWhereClause> {
  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
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

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
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

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
  ownerUserIdEqualToAnyMessageId(String ownerUserId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'owner_id_message_id',
          value: [ownerUserId],
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
  ownerUserIdNotEqualToAnyMessageId(String ownerUserId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_message_id',
                lower: [],
                upper: [ownerUserId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_message_id',
                lower: [ownerUserId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_message_id',
                lower: [ownerUserId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_message_id',
                lower: [],
                upper: [ownerUserId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
  ownerUserIdMessageIdEqualTo(String ownerUserId, String messageId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'owner_id_message_id',
          value: [ownerUserId, messageId],
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
  ownerUserIdEqualToMessageIdNotEqualTo(String ownerUserId, String messageId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_message_id',
                lower: [ownerUserId],
                upper: [ownerUserId, messageId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_message_id',
                lower: [ownerUserId, messageId],
                includeLower: false,
                upper: [ownerUserId],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_message_id',
                lower: [ownerUserId, messageId],
                includeLower: false,
                upper: [ownerUserId],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_message_id',
                lower: [ownerUserId],
                upper: [ownerUserId, messageId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
  conversationIdEqualTo(String conversationId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'conversation_id',
          value: [conversationId],
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
  conversationIdNotEqualTo(String conversationId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'conversation_id',
                lower: [],
                upper: [conversationId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'conversation_id',
                lower: [conversationId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'conversation_id',
                lower: [conversationId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'conversation_id',
                lower: [],
                upper: [conversationId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
  searchTokensElementEqualTo(String searchTokensElement) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'search_tokens',
          value: [searchTokensElement],
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
  searchTokensElementNotEqualTo(String searchTokensElement) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'search_tokens',
                lower: [],
                upper: [searchTokensElement],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'search_tokens',
                lower: [searchTokensElement],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'search_tokens',
                lower: [searchTokensElement],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'search_tokens',
                lower: [],
                upper: [searchTokensElement],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
  searchTokensElementGreaterThan(
    String searchTokensElement, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'search_tokens',
          lower: [searchTokensElement],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
  searchTokensElementLessThan(
    String searchTokensElement, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'search_tokens',
          lower: [],
          upper: [searchTokensElement],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
  searchTokensElementBetween(
    String lowerSearchTokensElement,
    String upperSearchTokensElement, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'search_tokens',
          lower: [lowerSearchTokensElement],
          includeLower: includeLower,
          upper: [upperSearchTokensElement],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
  searchTokensElementStartsWith(String SearchTokensElementPrefix) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'search_tokens',
          lower: [SearchTokensElementPrefix],
          upper: ['$SearchTokensElementPrefix\u{FFFFF}'],
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
  searchTokensElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'search_tokens', value: ['']),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
  searchTokensElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.lessThan(
                indexName: r'search_tokens',
                upper: [''],
              ),
            )
            .addWhereClause(
              IndexWhereClause.greaterThan(
                indexName: r'search_tokens',
                lower: [''],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.greaterThan(
                indexName: r'search_tokens',
                lower: [''],
              ),
            )
            .addWhereClause(
              IndexWhereClause.lessThan(
                indexName: r'search_tokens',
                upper: [''],
              ),
            );
      }
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
  createdAtMillisEqualTo(int createdAtMillis) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'created_at',
          value: [createdAtMillis],
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
  createdAtMillisNotEqualTo(int createdAtMillis) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'created_at',
                lower: [],
                upper: [createdAtMillis],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'created_at',
                lower: [createdAtMillis],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'created_at',
                lower: [createdAtMillis],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'created_at',
                lower: [],
                upper: [createdAtMillis],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
  createdAtMillisGreaterThan(int createdAtMillis, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'created_at',
          lower: [createdAtMillis],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
  createdAtMillisLessThan(int createdAtMillis, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'created_at',
          lower: [],
          upper: [createdAtMillis],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterWhereClause>
  createdAtMillisBetween(
    int lowerCreatedAtMillis,
    int upperCreatedAtMillis, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'created_at',
          lower: [lowerCreatedAtMillis],
          includeLower: includeLower,
          upper: [upperCreatedAtMillis],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension ChatMessageEntityQueryFilter
    on QueryBuilder<ChatMessageEntity, ChatMessageEntity, QFilterCondition> {
  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  accountIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  accountIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  accountIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  accountIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'account_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  accountIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  accountIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  accountIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  accountIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'account_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  accountIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'account_id', value: ''),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  accountIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'account_id', value: ''),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  bindingRevisionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'bind_rev', value: value),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  bindingRevisionGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'bind_rev',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  bindingRevisionLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'bind_rev',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  bindingRevisionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'bind_rev',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  conversationIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'conversation_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  conversationIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'conversation_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  conversationIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'conversation_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  conversationIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'conversation_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  conversationIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'conversation_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  conversationIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'conversation_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  conversationIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'conversation_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  conversationIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'conversation_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  conversationIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'conversation_id', value: ''),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  conversationIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'conversation_id', value: ''),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  createdAtMillisEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'created_at', value: value),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  createdAtMillisGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'created_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  createdAtMillisLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'created_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  createdAtMillisBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'created_at',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  deliveryStateEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'delivery_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  deliveryStateGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'delivery_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  deliveryStateLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'delivery_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  deliveryStateBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'delivery_state',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  deliveryStateStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'delivery_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  deliveryStateEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'delivery_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  deliveryStateContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'delivery_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  deliveryStateMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'delivery_state',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  deliveryStateIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'delivery_state', value: ''),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  deliveryStateIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'delivery_state', value: ''),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  directionEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'direction',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  directionGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'direction',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  directionLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'direction',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  directionBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'direction',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  directionStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'direction',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  directionEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'direction',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  directionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'direction',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  directionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'direction',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  directionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'direction', value: ''),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  directionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'direction', value: ''),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
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

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
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

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
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

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  messageKindEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  messageKindGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  messageKindLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  messageKindBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'kind',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  messageKindStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  messageKindEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  messageKindContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  messageKindMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'kind',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  messageKindIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'kind', value: ''),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  messageKindIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'kind', value: ''),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  messageBytesHexEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'message_bytes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  messageBytesHexGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'message_bytes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  messageBytesHexLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'message_bytes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  messageBytesHexBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'message_bytes',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  messageBytesHexStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'message_bytes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  messageBytesHexEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'message_bytes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  messageBytesHexContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'message_bytes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  messageBytesHexMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'message_bytes',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  messageBytesHexIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'message_bytes', value: ''),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  messageBytesHexIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'message_bytes', value: ''),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  messageIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'message_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  messageIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'message_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  messageIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'message_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  messageIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'message_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  messageIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'message_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  messageIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'message_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  messageIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'message_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  messageIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'message_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  messageIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'message_id', value: ''),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  messageIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'message_id', value: ''),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  ownerUserIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  ownerUserIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  ownerUserIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  ownerUserIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'owner_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  ownerUserIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  ownerUserIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  ownerUserIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  ownerUserIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'owner_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  ownerUserIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'owner_id', value: ''),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  ownerUserIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'owner_id', value: ''),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  payloadJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'payload_json'),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  payloadJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'payload_json'),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  payloadJsonEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'payload_json',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  payloadJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'payload_json',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  payloadJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'payload_json',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  payloadJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'payload_json',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  payloadJsonStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'payload_json',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  payloadJsonEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'payload_json',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  payloadJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'payload_json',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  payloadJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'payload_json',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  payloadJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'payload_json', value: ''),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  payloadJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'payload_json', value: ''),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  recipientUserIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'recipient_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  recipientUserIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'recipient_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  recipientUserIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'recipient_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  recipientUserIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'recipient_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  recipientUserIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'recipient_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  recipientUserIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'recipient_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  recipientUserIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'recipient_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  recipientUserIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'recipient_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  recipientUserIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'recipient_id', value: ''),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  recipientUserIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'recipient_id', value: ''),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  searchTokensElementEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'search_tokens',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  searchTokensElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'search_tokens',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  searchTokensElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'search_tokens',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  searchTokensElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'search_tokens',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  searchTokensElementStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'search_tokens',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  searchTokensElementEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'search_tokens',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  searchTokensElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'search_tokens',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  searchTokensElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'search_tokens',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  searchTokensElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'search_tokens', value: ''),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  searchTokensElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'search_tokens', value: ''),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  searchTokensLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'search_tokens', length, true, length, true);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  searchTokensIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'search_tokens', 0, true, 0, true);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  searchTokensIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'search_tokens', 0, false, 999999, true);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  searchTokensLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'search_tokens', 0, true, length, include);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  searchTokensLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'search_tokens', length, include, 999999, true);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  searchTokensLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'search_tokens',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  senderUserIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'sender_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  senderUserIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sender_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  senderUserIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sender_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  senderUserIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sender_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  senderUserIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'sender_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  senderUserIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'sender_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  senderUserIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'sender_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  senderUserIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'sender_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  senderUserIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'sender_id', value: ''),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
  senderUserIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'sender_id', value: ''),
      );
    });
  }
}

extension ChatMessageEntityQueryObject
    on QueryBuilder<ChatMessageEntity, ChatMessageEntity, QFilterCondition> {}

extension ChatMessageEntityQueryLinks
    on QueryBuilder<ChatMessageEntity, ChatMessageEntity, QFilterCondition> {}

extension ChatMessageEntityQuerySortBy
    on QueryBuilder<ChatMessageEntity, ChatMessageEntity, QSortBy> {
  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  sortByAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  sortByAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  sortByBindingRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bind_rev', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  sortByBindingRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bind_rev', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  sortByConversationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversation_id', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  sortByConversationIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversation_id', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  sortByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created_at', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  sortByCreatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created_at', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  sortByDeliveryState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'delivery_state', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  sortByDeliveryStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'delivery_state', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  sortByDirection() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'direction', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  sortByDirectionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'direction', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  sortByMessageKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  sortByMessageKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  sortByMessageBytesHex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message_bytes', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  sortByMessageBytesHexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message_bytes', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  sortByMessageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message_id', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  sortByMessageIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message_id', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  sortByOwnerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'owner_id', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  sortByOwnerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'owner_id', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  sortByPayloadJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payload_json', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  sortByPayloadJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payload_json', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  sortByRecipientUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recipient_id', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  sortByRecipientUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recipient_id', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  sortBySenderUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sender_id', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  sortBySenderUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sender_id', Sort.desc);
    });
  }
}

extension ChatMessageEntityQuerySortThenBy
    on QueryBuilder<ChatMessageEntity, ChatMessageEntity, QSortThenBy> {
  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  thenByAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  thenByAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  thenByBindingRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bind_rev', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  thenByBindingRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bind_rev', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  thenByConversationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversation_id', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  thenByConversationIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversation_id', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  thenByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created_at', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  thenByCreatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created_at', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  thenByDeliveryState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'delivery_state', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  thenByDeliveryStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'delivery_state', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  thenByDirection() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'direction', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  thenByDirectionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'direction', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  thenByMessageKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  thenByMessageKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  thenByMessageBytesHex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message_bytes', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  thenByMessageBytesHexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message_bytes', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  thenByMessageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message_id', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  thenByMessageIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message_id', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  thenByOwnerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'owner_id', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  thenByOwnerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'owner_id', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  thenByPayloadJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payload_json', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  thenByPayloadJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payload_json', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  thenByRecipientUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recipient_id', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  thenByRecipientUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recipient_id', Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  thenBySenderUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sender_id', Sort.asc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
  thenBySenderUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sender_id', Sort.desc);
    });
  }
}

extension ChatMessageEntityQueryWhereDistinct
    on QueryBuilder<ChatMessageEntity, ChatMessageEntity, QDistinct> {
  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QDistinct>
  distinctByAccountId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'account_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QDistinct>
  distinctByBindingRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'bind_rev');
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QDistinct>
  distinctByConversationId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'conversation_id',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QDistinct>
  distinctByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'created_at');
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QDistinct>
  distinctByDeliveryState({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'delivery_state',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QDistinct>
  distinctByDirection({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'direction', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QDistinct>
  distinctByMessageKind({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'kind', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QDistinct>
  distinctByMessageBytesHex({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'message_bytes',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QDistinct>
  distinctByMessageId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'message_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QDistinct>
  distinctByOwnerUserId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'owner_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QDistinct>
  distinctByPayloadJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'payload_json', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QDistinct>
  distinctByRecipientUserId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'recipient_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QDistinct>
  distinctBySearchTokens() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'search_tokens');
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QDistinct>
  distinctBySenderUserId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sender_id', caseSensitive: caseSensitive);
    });
  }
}

extension ChatMessageEntityQueryProperty
    on QueryBuilder<ChatMessageEntity, ChatMessageEntity, QQueryProperty> {
  QueryBuilder<ChatMessageEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ChatMessageEntity, String, QQueryOperations>
  accountIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'account_id');
    });
  }

  QueryBuilder<ChatMessageEntity, int, QQueryOperations>
  bindingRevisionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'bind_rev');
    });
  }

  QueryBuilder<ChatMessageEntity, String, QQueryOperations>
  conversationIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'conversation_id');
    });
  }

  QueryBuilder<ChatMessageEntity, int, QQueryOperations>
  createdAtMillisProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'created_at');
    });
  }

  QueryBuilder<ChatMessageEntity, String, QQueryOperations>
  deliveryStateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'delivery_state');
    });
  }

  QueryBuilder<ChatMessageEntity, String, QQueryOperations>
  directionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'direction');
    });
  }

  QueryBuilder<ChatMessageEntity, String, QQueryOperations>
  messageKindProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'kind');
    });
  }

  QueryBuilder<ChatMessageEntity, String, QQueryOperations>
  messageBytesHexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'message_bytes');
    });
  }

  QueryBuilder<ChatMessageEntity, String, QQueryOperations>
  messageIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'message_id');
    });
  }

  QueryBuilder<ChatMessageEntity, String, QQueryOperations>
  ownerUserIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'owner_id');
    });
  }

  QueryBuilder<ChatMessageEntity, String?, QQueryOperations>
  payloadJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'payload_json');
    });
  }

  QueryBuilder<ChatMessageEntity, String, QQueryOperations>
  recipientUserIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'recipient_id');
    });
  }

  QueryBuilder<ChatMessageEntity, List<String>, QQueryOperations>
  searchTokensProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'search_tokens');
    });
  }

  QueryBuilder<ChatMessageEntity, String, QQueryOperations>
  senderUserIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sender_id');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetChatOutboundQueueEntityCollection on Isar {
  IsarCollection<ChatOutboundQueueEntity> get chatOutboundQueueEntitys =>
      this.collection();
}

const ChatOutboundQueueEntitySchema = CollectionSchema(
  name: r'outbound',
  id: 9201902700275338765,
  properties: {
    r'conversation_id': PropertySchema(
      id: 0,
      name: r'conversation_id',
      type: IsarType.string,
    ),
    r'message_bytes': PropertySchema(
      id: 1,
      name: r'message_bytes',
      type: IsarType.string,
    ),
    r'message_id': PropertySchema(
      id: 2,
      name: r'message_id',
      type: IsarType.string,
    ),
    r'owner_id': PropertySchema(
      id: 3,
      name: r'owner_id',
      type: IsarType.string,
    ),
    r'recipient_id': PropertySchema(
      id: 4,
      name: r'recipient_id',
      type: IsarType.string,
    ),
    r'updated_at': PropertySchema(
      id: 5,
      name: r'updated_at',
      type: IsarType.long,
    ),
  },

  estimateSize: _chatOutboundQueueEntityEstimateSize,
  serialize: _chatOutboundQueueEntitySerialize,
  deserialize: _chatOutboundQueueEntityDeserialize,
  deserializeProp: _chatOutboundQueueEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'owner_id_message_id': IndexSchema(
      id: -5137609912169235308,
      name: r'owner_id_message_id',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'owner_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'message_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'conversation_id': IndexSchema(
      id: -4048954474591270722,
      name: r'conversation_id',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'conversation_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'updated_at': IndexSchema(
      id: -1449665799000962892,
      name: r'updated_at',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'updated_at',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _chatOutboundQueueEntityGetId,
  getLinks: _chatOutboundQueueEntityGetLinks,
  attach: _chatOutboundQueueEntityAttach,
  version: '3.3.2',
);

int _chatOutboundQueueEntityEstimateSize(
  ChatOutboundQueueEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.conversationId.length * 3;
  bytesCount += 3 + object.messageBytesHex.length * 3;
  bytesCount += 3 + object.messageId.length * 3;
  bytesCount += 3 + object.ownerUserId.length * 3;
  bytesCount += 3 + object.recipientUserId.length * 3;
  return bytesCount;
}

void _chatOutboundQueueEntitySerialize(
  ChatOutboundQueueEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.conversationId);
  writer.writeString(offsets[1], object.messageBytesHex);
  writer.writeString(offsets[2], object.messageId);
  writer.writeString(offsets[3], object.ownerUserId);
  writer.writeString(offsets[4], object.recipientUserId);
  writer.writeLong(offsets[5], object.updatedAtMillis);
}

ChatOutboundQueueEntity _chatOutboundQueueEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ChatOutboundQueueEntity();
  object.conversationId = reader.readString(offsets[0]);
  object.id = id;
  object.messageBytesHex = reader.readString(offsets[1]);
  object.messageId = reader.readString(offsets[2]);
  object.ownerUserId = reader.readString(offsets[3]);
  object.recipientUserId = reader.readString(offsets[4]);
  object.updatedAtMillis = reader.readLong(offsets[5]);
  return object;
}

P _chatOutboundQueueEntityDeserializeProp<P>(
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
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _chatOutboundQueueEntityGetId(ChatOutboundQueueEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _chatOutboundQueueEntityGetLinks(
  ChatOutboundQueueEntity object,
) {
  return [];
}

void _chatOutboundQueueEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  ChatOutboundQueueEntity object,
) {
  object.id = id;
}

extension ChatOutboundQueueEntityByIndex
    on IsarCollection<ChatOutboundQueueEntity> {
  Future<ChatOutboundQueueEntity?> getByOwnerUserIdMessageId(
    String ownerUserId,
    String messageId,
  ) {
    return getByIndex(r'owner_id_message_id', [ownerUserId, messageId]);
  }

  ChatOutboundQueueEntity? getByOwnerUserIdMessageIdSync(
    String ownerUserId,
    String messageId,
  ) {
    return getByIndexSync(r'owner_id_message_id', [ownerUserId, messageId]);
  }

  Future<bool> deleteByOwnerUserIdMessageId(
    String ownerUserId,
    String messageId,
  ) {
    return deleteByIndex(r'owner_id_message_id', [ownerUserId, messageId]);
  }

  bool deleteByOwnerUserIdMessageIdSync(String ownerUserId, String messageId) {
    return deleteByIndexSync(r'owner_id_message_id', [ownerUserId, messageId]);
  }

  Future<List<ChatOutboundQueueEntity?>> getAllByOwnerUserIdMessageId(
    List<String> ownerUserIdValues,
    List<String> messageIdValues,
  ) {
    final len = ownerUserIdValues.length;
    assert(
      messageIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerUserIdValues[i], messageIdValues[i]]);
    }

    return getAllByIndex(r'owner_id_message_id', values);
  }

  List<ChatOutboundQueueEntity?> getAllByOwnerUserIdMessageIdSync(
    List<String> ownerUserIdValues,
    List<String> messageIdValues,
  ) {
    final len = ownerUserIdValues.length;
    assert(
      messageIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerUserIdValues[i], messageIdValues[i]]);
    }

    return getAllByIndexSync(r'owner_id_message_id', values);
  }

  Future<int> deleteAllByOwnerUserIdMessageId(
    List<String> ownerUserIdValues,
    List<String> messageIdValues,
  ) {
    final len = ownerUserIdValues.length;
    assert(
      messageIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerUserIdValues[i], messageIdValues[i]]);
    }

    return deleteAllByIndex(r'owner_id_message_id', values);
  }

  int deleteAllByOwnerUserIdMessageIdSync(
    List<String> ownerUserIdValues,
    List<String> messageIdValues,
  ) {
    final len = ownerUserIdValues.length;
    assert(
      messageIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerUserIdValues[i], messageIdValues[i]]);
    }

    return deleteAllByIndexSync(r'owner_id_message_id', values);
  }

  Future<Id> putByOwnerUserIdMessageId(ChatOutboundQueueEntity object) {
    return putByIndex(r'owner_id_message_id', object);
  }

  Id putByOwnerUserIdMessageIdSync(
    ChatOutboundQueueEntity object, {
    bool saveLinks = true,
  }) {
    return putByIndexSync(r'owner_id_message_id', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByOwnerUserIdMessageId(
    List<ChatOutboundQueueEntity> objects,
  ) {
    return putAllByIndex(r'owner_id_message_id', objects);
  }

  List<Id> putAllByOwnerUserIdMessageIdSync(
    List<ChatOutboundQueueEntity> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(
      r'owner_id_message_id',
      objects,
      saveLinks: saveLinks,
    );
  }
}

extension ChatOutboundQueueEntityQueryWhereSort
    on QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QWhere> {
  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterWhere>
  anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterWhere>
  anyUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'updated_at'),
      );
    });
  }
}

extension ChatOutboundQueueEntityQueryWhere
    on
        QueryBuilder<
          ChatOutboundQueueEntity,
          ChatOutboundQueueEntity,
          QWhereClause
        > {
  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterWhereClause
  >
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterWhereClause
  >
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

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterWhereClause
  >
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterWhereClause
  >
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterWhereClause
  >
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

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterWhereClause
  >
  ownerUserIdEqualToAnyMessageId(String ownerUserId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'owner_id_message_id',
          value: [ownerUserId],
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterWhereClause
  >
  ownerUserIdNotEqualToAnyMessageId(String ownerUserId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_message_id',
                lower: [],
                upper: [ownerUserId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_message_id',
                lower: [ownerUserId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_message_id',
                lower: [ownerUserId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_message_id',
                lower: [],
                upper: [ownerUserId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterWhereClause
  >
  ownerUserIdMessageIdEqualTo(String ownerUserId, String messageId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'owner_id_message_id',
          value: [ownerUserId, messageId],
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterWhereClause
  >
  ownerUserIdEqualToMessageIdNotEqualTo(String ownerUserId, String messageId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_message_id',
                lower: [ownerUserId],
                upper: [ownerUserId, messageId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_message_id',
                lower: [ownerUserId, messageId],
                includeLower: false,
                upper: [ownerUserId],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_message_id',
                lower: [ownerUserId, messageId],
                includeLower: false,
                upper: [ownerUserId],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_message_id',
                lower: [ownerUserId],
                upper: [ownerUserId, messageId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterWhereClause
  >
  conversationIdEqualTo(String conversationId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'conversation_id',
          value: [conversationId],
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterWhereClause
  >
  conversationIdNotEqualTo(String conversationId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'conversation_id',
                lower: [],
                upper: [conversationId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'conversation_id',
                lower: [conversationId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'conversation_id',
                lower: [conversationId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'conversation_id',
                lower: [],
                upper: [conversationId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterWhereClause
  >
  updatedAtMillisEqualTo(int updatedAtMillis) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'updated_at',
          value: [updatedAtMillis],
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterWhereClause
  >
  updatedAtMillisNotEqualTo(int updatedAtMillis) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'updated_at',
                lower: [],
                upper: [updatedAtMillis],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'updated_at',
                lower: [updatedAtMillis],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'updated_at',
                lower: [updatedAtMillis],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'updated_at',
                lower: [],
                upper: [updatedAtMillis],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterWhereClause
  >
  updatedAtMillisGreaterThan(int updatedAtMillis, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'updated_at',
          lower: [updatedAtMillis],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterWhereClause
  >
  updatedAtMillisLessThan(int updatedAtMillis, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'updated_at',
          lower: [],
          upper: [updatedAtMillis],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterWhereClause
  >
  updatedAtMillisBetween(
    int lowerUpdatedAtMillis,
    int upperUpdatedAtMillis, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'updated_at',
          lower: [lowerUpdatedAtMillis],
          includeLower: includeLower,
          upper: [upperUpdatedAtMillis],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension ChatOutboundQueueEntityQueryFilter
    on
        QueryBuilder<
          ChatOutboundQueueEntity,
          ChatOutboundQueueEntity,
          QFilterCondition
        > {
  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  conversationIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'conversation_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  conversationIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'conversation_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  conversationIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'conversation_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  conversationIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'conversation_id',
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
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  conversationIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'conversation_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  conversationIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'conversation_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  conversationIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'conversation_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  conversationIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'conversation_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  conversationIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'conversation_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  conversationIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'conversation_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
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
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
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
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
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
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
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
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  messageBytesHexEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'message_bytes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  messageBytesHexGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'message_bytes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  messageBytesHexLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'message_bytes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  messageBytesHexBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'message_bytes',
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
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  messageBytesHexStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'message_bytes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  messageBytesHexEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'message_bytes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  messageBytesHexContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'message_bytes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  messageBytesHexMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'message_bytes',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  messageBytesHexIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'message_bytes', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  messageBytesHexIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'message_bytes', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  messageIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'message_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  messageIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'message_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  messageIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'message_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  messageIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'message_id',
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
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  messageIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'message_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  messageIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'message_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  messageIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'message_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  messageIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'message_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  messageIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'message_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  messageIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'message_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  ownerUserIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  ownerUserIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  ownerUserIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  ownerUserIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'owner_id',
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
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  ownerUserIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  ownerUserIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  ownerUserIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  ownerUserIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'owner_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  ownerUserIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'owner_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  ownerUserIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'owner_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  recipientUserIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'recipient_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  recipientUserIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'recipient_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  recipientUserIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'recipient_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  recipientUserIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'recipient_id',
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
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  recipientUserIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'recipient_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  recipientUserIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'recipient_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  recipientUserIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'recipient_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  recipientUserIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'recipient_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  recipientUserIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'recipient_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  recipientUserIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'recipient_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  updatedAtMillisEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'updated_at', value: value),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  updatedAtMillisGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'updated_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  updatedAtMillisLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'updated_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutboundQueueEntity,
    ChatOutboundQueueEntity,
    QAfterFilterCondition
  >
  updatedAtMillisBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'updated_at',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension ChatOutboundQueueEntityQueryObject
    on
        QueryBuilder<
          ChatOutboundQueueEntity,
          ChatOutboundQueueEntity,
          QFilterCondition
        > {}

extension ChatOutboundQueueEntityQueryLinks
    on
        QueryBuilder<
          ChatOutboundQueueEntity,
          ChatOutboundQueueEntity,
          QFilterCondition
        > {}

extension ChatOutboundQueueEntityQuerySortBy
    on QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QSortBy> {
  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
  sortByConversationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversation_id', Sort.asc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
  sortByConversationIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversation_id', Sort.desc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
  sortByMessageBytesHex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message_bytes', Sort.asc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
  sortByMessageBytesHexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message_bytes', Sort.desc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
  sortByMessageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message_id', Sort.asc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
  sortByMessageIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message_id', Sort.desc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
  sortByOwnerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'owner_id', Sort.asc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
  sortByOwnerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'owner_id', Sort.desc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
  sortByRecipientUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recipient_id', Sort.asc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
  sortByRecipientUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recipient_id', Sort.desc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
  sortByUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updated_at', Sort.asc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
  sortByUpdatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updated_at', Sort.desc);
    });
  }
}

extension ChatOutboundQueueEntityQuerySortThenBy
    on
        QueryBuilder<
          ChatOutboundQueueEntity,
          ChatOutboundQueueEntity,
          QSortThenBy
        > {
  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
  thenByConversationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversation_id', Sort.asc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
  thenByConversationIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversation_id', Sort.desc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
  thenByMessageBytesHex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message_bytes', Sort.asc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
  thenByMessageBytesHexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message_bytes', Sort.desc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
  thenByMessageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message_id', Sort.asc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
  thenByMessageIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message_id', Sort.desc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
  thenByOwnerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'owner_id', Sort.asc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
  thenByOwnerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'owner_id', Sort.desc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
  thenByRecipientUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recipient_id', Sort.asc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
  thenByRecipientUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recipient_id', Sort.desc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
  thenByUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updated_at', Sort.asc);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QAfterSortBy>
  thenByUpdatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updated_at', Sort.desc);
    });
  }
}

extension ChatOutboundQueueEntityQueryWhereDistinct
    on
        QueryBuilder<
          ChatOutboundQueueEntity,
          ChatOutboundQueueEntity,
          QDistinct
        > {
  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QDistinct>
  distinctByConversationId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'conversation_id',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QDistinct>
  distinctByMessageBytesHex({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'message_bytes',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QDistinct>
  distinctByMessageId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'message_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QDistinct>
  distinctByOwnerUserId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'owner_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QDistinct>
  distinctByRecipientUserId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'recipient_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, ChatOutboundQueueEntity, QDistinct>
  distinctByUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updated_at');
    });
  }
}

extension ChatOutboundQueueEntityQueryProperty
    on
        QueryBuilder<
          ChatOutboundQueueEntity,
          ChatOutboundQueueEntity,
          QQueryProperty
        > {
  QueryBuilder<ChatOutboundQueueEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, String, QQueryOperations>
  conversationIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'conversation_id');
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, String, QQueryOperations>
  messageBytesHexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'message_bytes');
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, String, QQueryOperations>
  messageIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'message_id');
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, String, QQueryOperations>
  ownerUserIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'owner_id');
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, String, QQueryOperations>
  recipientUserIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'recipient_id');
    });
  }

  QueryBuilder<ChatOutboundQueueEntity, int, QQueryOperations>
  updatedAtMillisProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updated_at');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetChatOutgoingMediaEntityCollection on Isar {
  IsarCollection<ChatOutgoingMediaEntity> get chatOutgoingMediaEntitys =>
      this.collection();
}

const ChatOutgoingMediaEntitySchema = CollectionSchema(
  name: r'media',
  id: -460020576612860404,
  properties: {
    r'attachment_id': PropertySchema(
      id: 0,
      name: r'attachment_id',
      type: IsarType.string,
    ),
    r'byte_size': PropertySchema(
      id: 1,
      name: r'byte_size',
      type: IsarType.long,
    ),
    r'content_type': PropertySchema(
      id: 2,
      name: r'content_type',
      type: IsarType.string,
    ),
    r'conversation_id': PropertySchema(
      id: 3,
      name: r'conversation_id',
      type: IsarType.string,
    ),
    r'created_at': PropertySchema(
      id: 4,
      name: r'created_at',
      type: IsarType.long,
    ),
    r'file_name': PropertySchema(
      id: 5,
      name: r'file_name',
      type: IsarType.string,
    ),
    r'owner_id': PropertySchema(
      id: 6,
      name: r'owner_id',
      type: IsarType.string,
    ),
    r'recipient_id': PropertySchema(
      id: 7,
      name: r'recipient_id',
      type: IsarType.string,
    ),
  },

  estimateSize: _chatOutgoingMediaEntityEstimateSize,
  serialize: _chatOutgoingMediaEntitySerialize,
  deserialize: _chatOutgoingMediaEntityDeserialize,
  deserializeProp: _chatOutgoingMediaEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'owner_id_attachment_id_recipient_id': IndexSchema(
      id: -3397802541012224692,
      name: r'owner_id_attachment_id_recipient_id',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'owner_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'attachment_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'recipient_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'attachment_id': IndexSchema(
      id: -5080068661376432091,
      name: r'attachment_id',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'attachment_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'recipient_id': IndexSchema(
      id: -4930864323911450737,
      name: r'recipient_id',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'recipient_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _chatOutgoingMediaEntityGetId,
  getLinks: _chatOutgoingMediaEntityGetLinks,
  attach: _chatOutgoingMediaEntityAttach,
  version: '3.3.2',
);

int _chatOutgoingMediaEntityEstimateSize(
  ChatOutgoingMediaEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.attachmentId.length * 3;
  bytesCount += 3 + object.contentType.length * 3;
  bytesCount += 3 + object.conversationId.length * 3;
  bytesCount += 3 + object.fileName.length * 3;
  bytesCount += 3 + object.ownerUserId.length * 3;
  bytesCount += 3 + object.recipientUserId.length * 3;
  return bytesCount;
}

void _chatOutgoingMediaEntitySerialize(
  ChatOutgoingMediaEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.attachmentId);
  writer.writeLong(offsets[1], object.byteSize);
  writer.writeString(offsets[2], object.contentType);
  writer.writeString(offsets[3], object.conversationId);
  writer.writeLong(offsets[4], object.createdAtMillis);
  writer.writeString(offsets[5], object.fileName);
  writer.writeString(offsets[6], object.ownerUserId);
  writer.writeString(offsets[7], object.recipientUserId);
}

ChatOutgoingMediaEntity _chatOutgoingMediaEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ChatOutgoingMediaEntity();
  object.attachmentId = reader.readString(offsets[0]);
  object.byteSize = reader.readLong(offsets[1]);
  object.contentType = reader.readString(offsets[2]);
  object.conversationId = reader.readString(offsets[3]);
  object.createdAtMillis = reader.readLong(offsets[4]);
  object.fileName = reader.readString(offsets[5]);
  object.id = id;
  object.ownerUserId = reader.readString(offsets[6]);
  object.recipientUserId = reader.readString(offsets[7]);
  return object;
}

P _chatOutgoingMediaEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _chatOutgoingMediaEntityGetId(ChatOutgoingMediaEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _chatOutgoingMediaEntityGetLinks(
  ChatOutgoingMediaEntity object,
) {
  return [];
}

void _chatOutgoingMediaEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  ChatOutgoingMediaEntity object,
) {
  object.id = id;
}

extension ChatOutgoingMediaEntityByIndex
    on IsarCollection<ChatOutgoingMediaEntity> {
  Future<ChatOutgoingMediaEntity?> getByOwnerUserIdAttachmentIdRecipientUserId(
    String ownerUserId,
    String attachmentId,
    String recipientUserId,
  ) {
    return getByIndex(r'owner_id_attachment_id_recipient_id', [
      ownerUserId,
      attachmentId,
      recipientUserId,
    ]);
  }

  ChatOutgoingMediaEntity? getByOwnerUserIdAttachmentIdRecipientUserIdSync(
    String ownerUserId,
    String attachmentId,
    String recipientUserId,
  ) {
    return getByIndexSync(r'owner_id_attachment_id_recipient_id', [
      ownerUserId,
      attachmentId,
      recipientUserId,
    ]);
  }

  Future<bool> deleteByOwnerUserIdAttachmentIdRecipientUserId(
    String ownerUserId,
    String attachmentId,
    String recipientUserId,
  ) {
    return deleteByIndex(r'owner_id_attachment_id_recipient_id', [
      ownerUserId,
      attachmentId,
      recipientUserId,
    ]);
  }

  bool deleteByOwnerUserIdAttachmentIdRecipientUserIdSync(
    String ownerUserId,
    String attachmentId,
    String recipientUserId,
  ) {
    return deleteByIndexSync(r'owner_id_attachment_id_recipient_id', [
      ownerUserId,
      attachmentId,
      recipientUserId,
    ]);
  }

  Future<List<ChatOutgoingMediaEntity?>>
  getAllByOwnerUserIdAttachmentIdRecipientUserId(
    List<String> ownerUserIdValues,
    List<String> attachmentIdValues,
    List<String> recipientUserIdValues,
  ) {
    final len = ownerUserIdValues.length;
    assert(
      attachmentIdValues.length == len && recipientUserIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([
        ownerUserIdValues[i],
        attachmentIdValues[i],
        recipientUserIdValues[i],
      ]);
    }

    return getAllByIndex(r'owner_id_attachment_id_recipient_id', values);
  }

  List<ChatOutgoingMediaEntity?>
  getAllByOwnerUserIdAttachmentIdRecipientUserIdSync(
    List<String> ownerUserIdValues,
    List<String> attachmentIdValues,
    List<String> recipientUserIdValues,
  ) {
    final len = ownerUserIdValues.length;
    assert(
      attachmentIdValues.length == len && recipientUserIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([
        ownerUserIdValues[i],
        attachmentIdValues[i],
        recipientUserIdValues[i],
      ]);
    }

    return getAllByIndexSync(r'owner_id_attachment_id_recipient_id', values);
  }

  Future<int> deleteAllByOwnerUserIdAttachmentIdRecipientUserId(
    List<String> ownerUserIdValues,
    List<String> attachmentIdValues,
    List<String> recipientUserIdValues,
  ) {
    final len = ownerUserIdValues.length;
    assert(
      attachmentIdValues.length == len && recipientUserIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([
        ownerUserIdValues[i],
        attachmentIdValues[i],
        recipientUserIdValues[i],
      ]);
    }

    return deleteAllByIndex(r'owner_id_attachment_id_recipient_id', values);
  }

  int deleteAllByOwnerUserIdAttachmentIdRecipientUserIdSync(
    List<String> ownerUserIdValues,
    List<String> attachmentIdValues,
    List<String> recipientUserIdValues,
  ) {
    final len = ownerUserIdValues.length;
    assert(
      attachmentIdValues.length == len && recipientUserIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([
        ownerUserIdValues[i],
        attachmentIdValues[i],
        recipientUserIdValues[i],
      ]);
    }

    return deleteAllByIndexSync(r'owner_id_attachment_id_recipient_id', values);
  }

  Future<Id> putByOwnerUserIdAttachmentIdRecipientUserId(
    ChatOutgoingMediaEntity object,
  ) {
    return putByIndex(r'owner_id_attachment_id_recipient_id', object);
  }

  Id putByOwnerUserIdAttachmentIdRecipientUserIdSync(
    ChatOutgoingMediaEntity object, {
    bool saveLinks = true,
  }) {
    return putByIndexSync(
      r'owner_id_attachment_id_recipient_id',
      object,
      saveLinks: saveLinks,
    );
  }

  Future<List<Id>> putAllByOwnerUserIdAttachmentIdRecipientUserId(
    List<ChatOutgoingMediaEntity> objects,
  ) {
    return putAllByIndex(r'owner_id_attachment_id_recipient_id', objects);
  }

  List<Id> putAllByOwnerUserIdAttachmentIdRecipientUserIdSync(
    List<ChatOutgoingMediaEntity> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(
      r'owner_id_attachment_id_recipient_id',
      objects,
      saveLinks: saveLinks,
    );
  }
}

extension ChatOutgoingMediaEntityQueryWhereSort
    on QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QWhere> {
  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterWhere>
  anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ChatOutgoingMediaEntityQueryWhere
    on
        QueryBuilder<
          ChatOutgoingMediaEntity,
          ChatOutgoingMediaEntity,
          QWhereClause
        > {
  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterWhereClause
  >
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterWhereClause
  >
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

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterWhereClause
  >
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterWhereClause
  >
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterWhereClause
  >
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

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterWhereClause
  >
  ownerUserIdEqualToAnyAttachmentIdRecipientUserId(String ownerUserId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'owner_id_attachment_id_recipient_id',
          value: [ownerUserId],
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterWhereClause
  >
  ownerUserIdNotEqualToAnyAttachmentIdRecipientUserId(String ownerUserId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_attachment_id_recipient_id',
                lower: [],
                upper: [ownerUserId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_attachment_id_recipient_id',
                lower: [ownerUserId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_attachment_id_recipient_id',
                lower: [ownerUserId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_attachment_id_recipient_id',
                lower: [],
                upper: [ownerUserId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterWhereClause
  >
  ownerUserIdAttachmentIdEqualToAnyRecipientUserId(
    String ownerUserId,
    String attachmentId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'owner_id_attachment_id_recipient_id',
          value: [ownerUserId, attachmentId],
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterWhereClause
  >
  ownerUserIdEqualToAttachmentIdNotEqualToAnyRecipientUserId(
    String ownerUserId,
    String attachmentId,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_attachment_id_recipient_id',
                lower: [ownerUserId],
                upper: [ownerUserId, attachmentId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_attachment_id_recipient_id',
                lower: [ownerUserId, attachmentId],
                includeLower: false,
                upper: [ownerUserId],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_attachment_id_recipient_id',
                lower: [ownerUserId, attachmentId],
                includeLower: false,
                upper: [ownerUserId],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_attachment_id_recipient_id',
                lower: [ownerUserId],
                upper: [ownerUserId, attachmentId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterWhereClause
  >
  ownerUserIdAttachmentIdRecipientUserIdEqualTo(
    String ownerUserId,
    String attachmentId,
    String recipientUserId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'owner_id_attachment_id_recipient_id',
          value: [ownerUserId, attachmentId, recipientUserId],
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterWhereClause
  >
  ownerUserIdAttachmentIdEqualToRecipientUserIdNotEqualTo(
    String ownerUserId,
    String attachmentId,
    String recipientUserId,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_attachment_id_recipient_id',
                lower: [ownerUserId, attachmentId],
                upper: [ownerUserId, attachmentId, recipientUserId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_attachment_id_recipient_id',
                lower: [ownerUserId, attachmentId, recipientUserId],
                includeLower: false,
                upper: [ownerUserId, attachmentId],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_attachment_id_recipient_id',
                lower: [ownerUserId, attachmentId, recipientUserId],
                includeLower: false,
                upper: [ownerUserId, attachmentId],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_attachment_id_recipient_id',
                lower: [ownerUserId, attachmentId],
                upper: [ownerUserId, attachmentId, recipientUserId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterWhereClause
  >
  attachmentIdEqualTo(String attachmentId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'attachment_id',
          value: [attachmentId],
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterWhereClause
  >
  attachmentIdNotEqualTo(String attachmentId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'attachment_id',
                lower: [],
                upper: [attachmentId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'attachment_id',
                lower: [attachmentId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'attachment_id',
                lower: [attachmentId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'attachment_id',
                lower: [],
                upper: [attachmentId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterWhereClause
  >
  recipientUserIdEqualTo(String recipientUserId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'recipient_id',
          value: [recipientUserId],
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterWhereClause
  >
  recipientUserIdNotEqualTo(String recipientUserId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'recipient_id',
                lower: [],
                upper: [recipientUserId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'recipient_id',
                lower: [recipientUserId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'recipient_id',
                lower: [recipientUserId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'recipient_id',
                lower: [],
                upper: [recipientUserId],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension ChatOutgoingMediaEntityQueryFilter
    on
        QueryBuilder<
          ChatOutgoingMediaEntity,
          ChatOutgoingMediaEntity,
          QFilterCondition
        > {
  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  attachmentIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'attachment_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  attachmentIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'attachment_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  attachmentIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'attachment_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  attachmentIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'attachment_id',
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
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  attachmentIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'attachment_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  attachmentIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'attachment_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  attachmentIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'attachment_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  attachmentIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'attachment_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  attachmentIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'attachment_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  attachmentIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'attachment_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  byteSizeEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'byte_size', value: value),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  byteSizeGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'byte_size',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  byteSizeLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'byte_size',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  byteSizeBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'byte_size',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  contentTypeEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'content_type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  contentTypeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'content_type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  contentTypeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'content_type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  contentTypeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'content_type',
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
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  contentTypeStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'content_type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  contentTypeEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'content_type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  contentTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'content_type',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  contentTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'content_type',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  contentTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'content_type', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  contentTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'content_type', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  conversationIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'conversation_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  conversationIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'conversation_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  conversationIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'conversation_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  conversationIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'conversation_id',
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
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  conversationIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'conversation_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  conversationIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'conversation_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  conversationIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'conversation_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  conversationIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'conversation_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  conversationIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'conversation_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  conversationIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'conversation_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  createdAtMillisEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'created_at', value: value),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  createdAtMillisGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'created_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  createdAtMillisLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'created_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  createdAtMillisBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'created_at',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  fileNameEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'file_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  fileNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'file_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  fileNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'file_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  fileNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'file_name',
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
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  fileNameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'file_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  fileNameEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'file_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  fileNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'file_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  fileNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'file_name',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  fileNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'file_name', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  fileNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'file_name', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
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
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
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
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
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
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
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
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  ownerUserIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  ownerUserIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  ownerUserIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  ownerUserIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'owner_id',
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
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  ownerUserIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  ownerUserIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  ownerUserIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  ownerUserIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'owner_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  ownerUserIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'owner_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  ownerUserIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'owner_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  recipientUserIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'recipient_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  recipientUserIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'recipient_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  recipientUserIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'recipient_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  recipientUserIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'recipient_id',
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
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  recipientUserIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'recipient_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  recipientUserIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'recipient_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  recipientUserIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'recipient_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  recipientUserIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'recipient_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  recipientUserIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'recipient_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatOutgoingMediaEntity,
    ChatOutgoingMediaEntity,
    QAfterFilterCondition
  >
  recipientUserIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'recipient_id', value: ''),
      );
    });
  }
}

extension ChatOutgoingMediaEntityQueryObject
    on
        QueryBuilder<
          ChatOutgoingMediaEntity,
          ChatOutgoingMediaEntity,
          QFilterCondition
        > {}

extension ChatOutgoingMediaEntityQueryLinks
    on
        QueryBuilder<
          ChatOutgoingMediaEntity,
          ChatOutgoingMediaEntity,
          QFilterCondition
        > {}

extension ChatOutgoingMediaEntityQuerySortBy
    on QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QSortBy> {
  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
  sortByAttachmentId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attachment_id', Sort.asc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
  sortByAttachmentIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attachment_id', Sort.desc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
  sortByByteSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'byte_size', Sort.asc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
  sortByByteSizeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'byte_size', Sort.desc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
  sortByContentType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content_type', Sort.asc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
  sortByContentTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content_type', Sort.desc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
  sortByConversationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversation_id', Sort.asc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
  sortByConversationIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversation_id', Sort.desc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
  sortByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created_at', Sort.asc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
  sortByCreatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created_at', Sort.desc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
  sortByFileName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'file_name', Sort.asc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
  sortByFileNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'file_name', Sort.desc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
  sortByOwnerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'owner_id', Sort.asc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
  sortByOwnerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'owner_id', Sort.desc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
  sortByRecipientUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recipient_id', Sort.asc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
  sortByRecipientUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recipient_id', Sort.desc);
    });
  }
}

extension ChatOutgoingMediaEntityQuerySortThenBy
    on
        QueryBuilder<
          ChatOutgoingMediaEntity,
          ChatOutgoingMediaEntity,
          QSortThenBy
        > {
  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
  thenByAttachmentId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attachment_id', Sort.asc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
  thenByAttachmentIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attachment_id', Sort.desc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
  thenByByteSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'byte_size', Sort.asc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
  thenByByteSizeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'byte_size', Sort.desc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
  thenByContentType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content_type', Sort.asc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
  thenByContentTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content_type', Sort.desc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
  thenByConversationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversation_id', Sort.asc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
  thenByConversationIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversation_id', Sort.desc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
  thenByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created_at', Sort.asc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
  thenByCreatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created_at', Sort.desc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
  thenByFileName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'file_name', Sort.asc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
  thenByFileNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'file_name', Sort.desc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
  thenByOwnerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'owner_id', Sort.asc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
  thenByOwnerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'owner_id', Sort.desc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
  thenByRecipientUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recipient_id', Sort.asc);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QAfterSortBy>
  thenByRecipientUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recipient_id', Sort.desc);
    });
  }
}

extension ChatOutgoingMediaEntityQueryWhereDistinct
    on
        QueryBuilder<
          ChatOutgoingMediaEntity,
          ChatOutgoingMediaEntity,
          QDistinct
        > {
  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QDistinct>
  distinctByAttachmentId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'attachment_id',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QDistinct>
  distinctByByteSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'byte_size');
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QDistinct>
  distinctByContentType({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'content_type', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QDistinct>
  distinctByConversationId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'conversation_id',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QDistinct>
  distinctByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'created_at');
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QDistinct>
  distinctByFileName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'file_name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QDistinct>
  distinctByOwnerUserId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'owner_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, ChatOutgoingMediaEntity, QDistinct>
  distinctByRecipientUserId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'recipient_id', caseSensitive: caseSensitive);
    });
  }
}

extension ChatOutgoingMediaEntityQueryProperty
    on
        QueryBuilder<
          ChatOutgoingMediaEntity,
          ChatOutgoingMediaEntity,
          QQueryProperty
        > {
  QueryBuilder<ChatOutgoingMediaEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, String, QQueryOperations>
  attachmentIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'attachment_id');
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, int, QQueryOperations>
  byteSizeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'byte_size');
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, String, QQueryOperations>
  contentTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'content_type');
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, String, QQueryOperations>
  conversationIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'conversation_id');
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, int, QQueryOperations>
  createdAtMillisProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'created_at');
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, String, QQueryOperations>
  fileNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'file_name');
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, String, QQueryOperations>
  ownerUserIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'owner_id');
    });
  }

  QueryBuilder<ChatOutgoingMediaEntity, String, QQueryOperations>
  recipientUserIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'recipient_id');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetChatPendingInboundEntityCollection on Isar {
  IsarCollection<ChatPendingInboundEntity> get chatPendingInboundEntitys =>
      this.collection();
}

const ChatPendingInboundEntitySchema = CollectionSchema(
  name: r'inbound',
  id: 8868688902405367814,
  properties: {
    r'conversation_id': PropertySchema(
      id: 0,
      name: r'conversation_id',
      type: IsarType.string,
    ),
    r'created_at': PropertySchema(
      id: 1,
      name: r'created_at',
      type: IsarType.long,
    ),
    r'message_bytes': PropertySchema(
      id: 2,
      name: r'message_bytes',
      type: IsarType.string,
    ),
    r'message_id': PropertySchema(
      id: 3,
      name: r'message_id',
      type: IsarType.string,
    ),
    r'owner_id': PropertySchema(
      id: 4,
      name: r'owner_id',
      type: IsarType.string,
    ),
  },

  estimateSize: _chatPendingInboundEntityEstimateSize,
  serialize: _chatPendingInboundEntitySerialize,
  deserialize: _chatPendingInboundEntityDeserialize,
  deserializeProp: _chatPendingInboundEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'owner_id_message_id': IndexSchema(
      id: -5137609912169235308,
      name: r'owner_id_message_id',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'owner_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'message_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'conversation_id': IndexSchema(
      id: -4048954474591270722,
      name: r'conversation_id',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'conversation_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'created_at': IndexSchema(
      id: 6296488693525790031,
      name: r'created_at',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'created_at',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _chatPendingInboundEntityGetId,
  getLinks: _chatPendingInboundEntityGetLinks,
  attach: _chatPendingInboundEntityAttach,
  version: '3.3.2',
);

int _chatPendingInboundEntityEstimateSize(
  ChatPendingInboundEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.conversationId.length * 3;
  bytesCount += 3 + object.messageBytesHex.length * 3;
  bytesCount += 3 + object.messageId.length * 3;
  bytesCount += 3 + object.ownerUserId.length * 3;
  return bytesCount;
}

void _chatPendingInboundEntitySerialize(
  ChatPendingInboundEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.conversationId);
  writer.writeLong(offsets[1], object.createdAtMillis);
  writer.writeString(offsets[2], object.messageBytesHex);
  writer.writeString(offsets[3], object.messageId);
  writer.writeString(offsets[4], object.ownerUserId);
}

ChatPendingInboundEntity _chatPendingInboundEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ChatPendingInboundEntity();
  object.conversationId = reader.readString(offsets[0]);
  object.createdAtMillis = reader.readLong(offsets[1]);
  object.id = id;
  object.messageBytesHex = reader.readString(offsets[2]);
  object.messageId = reader.readString(offsets[3]);
  object.ownerUserId = reader.readString(offsets[4]);
  return object;
}

P _chatPendingInboundEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _chatPendingInboundEntityGetId(ChatPendingInboundEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _chatPendingInboundEntityGetLinks(
  ChatPendingInboundEntity object,
) {
  return [];
}

void _chatPendingInboundEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  ChatPendingInboundEntity object,
) {
  object.id = id;
}

extension ChatPendingInboundEntityByIndex
    on IsarCollection<ChatPendingInboundEntity> {
  Future<ChatPendingInboundEntity?> getByOwnerUserIdMessageId(
    String ownerUserId,
    String messageId,
  ) {
    return getByIndex(r'owner_id_message_id', [ownerUserId, messageId]);
  }

  ChatPendingInboundEntity? getByOwnerUserIdMessageIdSync(
    String ownerUserId,
    String messageId,
  ) {
    return getByIndexSync(r'owner_id_message_id', [ownerUserId, messageId]);
  }

  Future<bool> deleteByOwnerUserIdMessageId(
    String ownerUserId,
    String messageId,
  ) {
    return deleteByIndex(r'owner_id_message_id', [ownerUserId, messageId]);
  }

  bool deleteByOwnerUserIdMessageIdSync(String ownerUserId, String messageId) {
    return deleteByIndexSync(r'owner_id_message_id', [ownerUserId, messageId]);
  }

  Future<List<ChatPendingInboundEntity?>> getAllByOwnerUserIdMessageId(
    List<String> ownerUserIdValues,
    List<String> messageIdValues,
  ) {
    final len = ownerUserIdValues.length;
    assert(
      messageIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerUserIdValues[i], messageIdValues[i]]);
    }

    return getAllByIndex(r'owner_id_message_id', values);
  }

  List<ChatPendingInboundEntity?> getAllByOwnerUserIdMessageIdSync(
    List<String> ownerUserIdValues,
    List<String> messageIdValues,
  ) {
    final len = ownerUserIdValues.length;
    assert(
      messageIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerUserIdValues[i], messageIdValues[i]]);
    }

    return getAllByIndexSync(r'owner_id_message_id', values);
  }

  Future<int> deleteAllByOwnerUserIdMessageId(
    List<String> ownerUserIdValues,
    List<String> messageIdValues,
  ) {
    final len = ownerUserIdValues.length;
    assert(
      messageIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerUserIdValues[i], messageIdValues[i]]);
    }

    return deleteAllByIndex(r'owner_id_message_id', values);
  }

  int deleteAllByOwnerUserIdMessageIdSync(
    List<String> ownerUserIdValues,
    List<String> messageIdValues,
  ) {
    final len = ownerUserIdValues.length;
    assert(
      messageIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerUserIdValues[i], messageIdValues[i]]);
    }

    return deleteAllByIndexSync(r'owner_id_message_id', values);
  }

  Future<Id> putByOwnerUserIdMessageId(ChatPendingInboundEntity object) {
    return putByIndex(r'owner_id_message_id', object);
  }

  Id putByOwnerUserIdMessageIdSync(
    ChatPendingInboundEntity object, {
    bool saveLinks = true,
  }) {
    return putByIndexSync(r'owner_id_message_id', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByOwnerUserIdMessageId(
    List<ChatPendingInboundEntity> objects,
  ) {
    return putAllByIndex(r'owner_id_message_id', objects);
  }

  List<Id> putAllByOwnerUserIdMessageIdSync(
    List<ChatPendingInboundEntity> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(
      r'owner_id_message_id',
      objects,
      saveLinks: saveLinks,
    );
  }
}

extension ChatPendingInboundEntityQueryWhereSort
    on
        QueryBuilder<
          ChatPendingInboundEntity,
          ChatPendingInboundEntity,
          QWhere
        > {
  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterWhere>
  anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterWhere>
  anyCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'created_at'),
      );
    });
  }
}

extension ChatPendingInboundEntityQueryWhere
    on
        QueryBuilder<
          ChatPendingInboundEntity,
          ChatPendingInboundEntity,
          QWhereClause
        > {
  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterWhereClause
  >
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterWhereClause
  >
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

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterWhereClause
  >
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterWhereClause
  >
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterWhereClause
  >
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

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterWhereClause
  >
  ownerUserIdEqualToAnyMessageId(String ownerUserId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'owner_id_message_id',
          value: [ownerUserId],
        ),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterWhereClause
  >
  ownerUserIdNotEqualToAnyMessageId(String ownerUserId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_message_id',
                lower: [],
                upper: [ownerUserId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_message_id',
                lower: [ownerUserId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_message_id',
                lower: [ownerUserId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_message_id',
                lower: [],
                upper: [ownerUserId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterWhereClause
  >
  ownerUserIdMessageIdEqualTo(String ownerUserId, String messageId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'owner_id_message_id',
          value: [ownerUserId, messageId],
        ),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterWhereClause
  >
  ownerUserIdEqualToMessageIdNotEqualTo(String ownerUserId, String messageId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_message_id',
                lower: [ownerUserId],
                upper: [ownerUserId, messageId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_message_id',
                lower: [ownerUserId, messageId],
                includeLower: false,
                upper: [ownerUserId],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_message_id',
                lower: [ownerUserId, messageId],
                includeLower: false,
                upper: [ownerUserId],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_message_id',
                lower: [ownerUserId],
                upper: [ownerUserId, messageId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterWhereClause
  >
  conversationIdEqualTo(String conversationId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'conversation_id',
          value: [conversationId],
        ),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterWhereClause
  >
  conversationIdNotEqualTo(String conversationId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'conversation_id',
                lower: [],
                upper: [conversationId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'conversation_id',
                lower: [conversationId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'conversation_id',
                lower: [conversationId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'conversation_id',
                lower: [],
                upper: [conversationId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterWhereClause
  >
  createdAtMillisEqualTo(int createdAtMillis) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'created_at',
          value: [createdAtMillis],
        ),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterWhereClause
  >
  createdAtMillisNotEqualTo(int createdAtMillis) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'created_at',
                lower: [],
                upper: [createdAtMillis],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'created_at',
                lower: [createdAtMillis],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'created_at',
                lower: [createdAtMillis],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'created_at',
                lower: [],
                upper: [createdAtMillis],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterWhereClause
  >
  createdAtMillisGreaterThan(int createdAtMillis, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'created_at',
          lower: [createdAtMillis],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterWhereClause
  >
  createdAtMillisLessThan(int createdAtMillis, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'created_at',
          lower: [],
          upper: [createdAtMillis],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterWhereClause
  >
  createdAtMillisBetween(
    int lowerCreatedAtMillis,
    int upperCreatedAtMillis, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'created_at',
          lower: [lowerCreatedAtMillis],
          includeLower: includeLower,
          upper: [upperCreatedAtMillis],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension ChatPendingInboundEntityQueryFilter
    on
        QueryBuilder<
          ChatPendingInboundEntity,
          ChatPendingInboundEntity,
          QFilterCondition
        > {
  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  conversationIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'conversation_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  conversationIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'conversation_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  conversationIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'conversation_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  conversationIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'conversation_id',
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
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  conversationIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'conversation_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  conversationIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'conversation_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  conversationIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'conversation_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  conversationIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'conversation_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  conversationIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'conversation_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  conversationIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'conversation_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  createdAtMillisEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'created_at', value: value),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  createdAtMillisGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'created_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  createdAtMillisLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'created_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  createdAtMillisBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'created_at',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
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
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
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
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
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
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
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
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  messageBytesHexEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'message_bytes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  messageBytesHexGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'message_bytes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  messageBytesHexLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'message_bytes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  messageBytesHexBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'message_bytes',
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
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  messageBytesHexStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'message_bytes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  messageBytesHexEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'message_bytes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  messageBytesHexContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'message_bytes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  messageBytesHexMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'message_bytes',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  messageBytesHexIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'message_bytes', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  messageBytesHexIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'message_bytes', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  messageIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'message_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  messageIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'message_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  messageIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'message_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  messageIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'message_id',
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
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  messageIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'message_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  messageIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'message_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  messageIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'message_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  messageIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'message_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  messageIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'message_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  messageIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'message_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  ownerUserIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  ownerUserIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  ownerUserIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  ownerUserIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'owner_id',
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
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  ownerUserIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  ownerUserIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  ownerUserIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  ownerUserIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'owner_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  ownerUserIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'owner_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatPendingInboundEntity,
    ChatPendingInboundEntity,
    QAfterFilterCondition
  >
  ownerUserIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'owner_id', value: ''),
      );
    });
  }
}

extension ChatPendingInboundEntityQueryObject
    on
        QueryBuilder<
          ChatPendingInboundEntity,
          ChatPendingInboundEntity,
          QFilterCondition
        > {}

extension ChatPendingInboundEntityQueryLinks
    on
        QueryBuilder<
          ChatPendingInboundEntity,
          ChatPendingInboundEntity,
          QFilterCondition
        > {}

extension ChatPendingInboundEntityQuerySortBy
    on
        QueryBuilder<
          ChatPendingInboundEntity,
          ChatPendingInboundEntity,
          QSortBy
        > {
  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
  sortByConversationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversation_id', Sort.asc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
  sortByConversationIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversation_id', Sort.desc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
  sortByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created_at', Sort.asc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
  sortByCreatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created_at', Sort.desc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
  sortByMessageBytesHex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message_bytes', Sort.asc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
  sortByMessageBytesHexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message_bytes', Sort.desc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
  sortByMessageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message_id', Sort.asc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
  sortByMessageIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message_id', Sort.desc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
  sortByOwnerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'owner_id', Sort.asc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
  sortByOwnerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'owner_id', Sort.desc);
    });
  }
}

extension ChatPendingInboundEntityQuerySortThenBy
    on
        QueryBuilder<
          ChatPendingInboundEntity,
          ChatPendingInboundEntity,
          QSortThenBy
        > {
  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
  thenByConversationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversation_id', Sort.asc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
  thenByConversationIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversation_id', Sort.desc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
  thenByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created_at', Sort.asc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
  thenByCreatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created_at', Sort.desc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
  thenByMessageBytesHex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message_bytes', Sort.asc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
  thenByMessageBytesHexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message_bytes', Sort.desc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
  thenByMessageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message_id', Sort.asc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
  thenByMessageIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message_id', Sort.desc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
  thenByOwnerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'owner_id', Sort.asc);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QAfterSortBy>
  thenByOwnerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'owner_id', Sort.desc);
    });
  }
}

extension ChatPendingInboundEntityQueryWhereDistinct
    on
        QueryBuilder<
          ChatPendingInboundEntity,
          ChatPendingInboundEntity,
          QDistinct
        > {
  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QDistinct>
  distinctByConversationId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'conversation_id',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QDistinct>
  distinctByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'created_at');
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QDistinct>
  distinctByMessageBytesHex({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'message_bytes',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QDistinct>
  distinctByMessageId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'message_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatPendingInboundEntity, ChatPendingInboundEntity, QDistinct>
  distinctByOwnerUserId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'owner_id', caseSensitive: caseSensitive);
    });
  }
}

extension ChatPendingInboundEntityQueryProperty
    on
        QueryBuilder<
          ChatPendingInboundEntity,
          ChatPendingInboundEntity,
          QQueryProperty
        > {
  QueryBuilder<ChatPendingInboundEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ChatPendingInboundEntity, String, QQueryOperations>
  conversationIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'conversation_id');
    });
  }

  QueryBuilder<ChatPendingInboundEntity, int, QQueryOperations>
  createdAtMillisProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'created_at');
    });
  }

  QueryBuilder<ChatPendingInboundEntity, String, QQueryOperations>
  messageBytesHexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'message_bytes');
    });
  }

  QueryBuilder<ChatPendingInboundEntity, String, QQueryOperations>
  messageIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'message_id');
    });
  }

  QueryBuilder<ChatPendingInboundEntity, String, QQueryOperations>
  ownerUserIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'owner_id');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetChatRouteCacheEntityCollection on Isar {
  IsarCollection<ChatRouteCacheEntity> get chatRouteCacheEntitys =>
      this.collection();
}

const ChatRouteCacheEntitySchema = CollectionSchema(
  name: r'route',
  id: 8686557153332962867,
  properties: {
    r'created_at': PropertySchema(
      id: 0,
      name: r'created_at',
      type: IsarType.long,
    ),
    r'device_id': PropertySchema(
      id: 1,
      name: r'device_id',
      type: IsarType.string,
    ),
    r'nearby_hint': PropertySchema(
      id: 2,
      name: r'nearby_hint',
      type: IsarType.string,
    ),
    r'owner_id': PropertySchema(
      id: 3,
      name: r'owner_id',
      type: IsarType.string,
    ),
    r'peer_id': PropertySchema(id: 4, name: r'peer_id', type: IsarType.string),
    r'route_name': PropertySchema(
      id: 5,
      name: r'route_name',
      type: IsarType.string,
    ),
    r'route_note': PropertySchema(
      id: 6,
      name: r'route_note',
      type: IsarType.string,
    ),
    r'safety_number': PropertySchema(
      id: 7,
      name: r'safety_number',
      type: IsarType.string,
    ),
    r'updated_at': PropertySchema(
      id: 8,
      name: r'updated_at',
      type: IsarType.long,
    ),
  },

  estimateSize: _chatRouteCacheEntityEstimateSize,
  serialize: _chatRouteCacheEntitySerialize,
  deserialize: _chatRouteCacheEntityDeserialize,
  deserializeProp: _chatRouteCacheEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'owner_id_peer_id': IndexSchema(
      id: -5230315218043329836,
      name: r'owner_id_peer_id',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'owner_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'peer_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _chatRouteCacheEntityGetId,
  getLinks: _chatRouteCacheEntityGetLinks,
  attach: _chatRouteCacheEntityAttach,
  version: '3.3.2',
);

int _chatRouteCacheEntityEstimateSize(
  ChatRouteCacheEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.deviceId.length * 3;
  {
    final value = object.nearbyPeerHint;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.ownerUserId.length * 3;
  bytesCount += 3 + object.peerUserId.length * 3;
  bytesCount += 3 + object.routeDisplayName.length * 3;
  {
    final value = object.note;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.safetyNumber.length * 3;
  return bytesCount;
}

void _chatRouteCacheEntitySerialize(
  ChatRouteCacheEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.createdAtMillis);
  writer.writeString(offsets[1], object.deviceId);
  writer.writeString(offsets[2], object.nearbyPeerHint);
  writer.writeString(offsets[3], object.ownerUserId);
  writer.writeString(offsets[4], object.peerUserId);
  writer.writeString(offsets[5], object.routeDisplayName);
  writer.writeString(offsets[6], object.note);
  writer.writeString(offsets[7], object.safetyNumber);
  writer.writeLong(offsets[8], object.updatedAtMillis);
}

ChatRouteCacheEntity _chatRouteCacheEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ChatRouteCacheEntity();
  object.createdAtMillis = reader.readLong(offsets[0]);
  object.deviceId = reader.readString(offsets[1]);
  object.id = id;
  object.nearbyPeerHint = reader.readStringOrNull(offsets[2]);
  object.ownerUserId = reader.readString(offsets[3]);
  object.peerUserId = reader.readString(offsets[4]);
  object.routeDisplayName = reader.readString(offsets[5]);
  object.note = reader.readStringOrNull(offsets[6]);
  object.safetyNumber = reader.readString(offsets[7]);
  object.updatedAtMillis = reader.readLong(offsets[8]);
  return object;
}

P _chatRouteCacheEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _chatRouteCacheEntityGetId(ChatRouteCacheEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _chatRouteCacheEntityGetLinks(
  ChatRouteCacheEntity object,
) {
  return [];
}

void _chatRouteCacheEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  ChatRouteCacheEntity object,
) {
  object.id = id;
}

extension ChatRouteCacheEntityByIndex on IsarCollection<ChatRouteCacheEntity> {
  Future<ChatRouteCacheEntity?> getByOwnerUserIdPeerUserId(
    String ownerUserId,
    String peerUserId,
  ) {
    return getByIndex(r'owner_id_peer_id', [ownerUserId, peerUserId]);
  }

  ChatRouteCacheEntity? getByOwnerUserIdPeerUserIdSync(
    String ownerUserId,
    String peerUserId,
  ) {
    return getByIndexSync(r'owner_id_peer_id', [ownerUserId, peerUserId]);
  }

  Future<bool> deleteByOwnerUserIdPeerUserId(
    String ownerUserId,
    String peerUserId,
  ) {
    return deleteByIndex(r'owner_id_peer_id', [ownerUserId, peerUserId]);
  }

  bool deleteByOwnerUserIdPeerUserIdSync(
    String ownerUserId,
    String peerUserId,
  ) {
    return deleteByIndexSync(r'owner_id_peer_id', [ownerUserId, peerUserId]);
  }

  Future<List<ChatRouteCacheEntity?>> getAllByOwnerUserIdPeerUserId(
    List<String> ownerUserIdValues,
    List<String> peerUserIdValues,
  ) {
    final len = ownerUserIdValues.length;
    assert(
      peerUserIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerUserIdValues[i], peerUserIdValues[i]]);
    }

    return getAllByIndex(r'owner_id_peer_id', values);
  }

  List<ChatRouteCacheEntity?> getAllByOwnerUserIdPeerUserIdSync(
    List<String> ownerUserIdValues,
    List<String> peerUserIdValues,
  ) {
    final len = ownerUserIdValues.length;
    assert(
      peerUserIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerUserIdValues[i], peerUserIdValues[i]]);
    }

    return getAllByIndexSync(r'owner_id_peer_id', values);
  }

  Future<int> deleteAllByOwnerUserIdPeerUserId(
    List<String> ownerUserIdValues,
    List<String> peerUserIdValues,
  ) {
    final len = ownerUserIdValues.length;
    assert(
      peerUserIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerUserIdValues[i], peerUserIdValues[i]]);
    }

    return deleteAllByIndex(r'owner_id_peer_id', values);
  }

  int deleteAllByOwnerUserIdPeerUserIdSync(
    List<String> ownerUserIdValues,
    List<String> peerUserIdValues,
  ) {
    final len = ownerUserIdValues.length;
    assert(
      peerUserIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerUserIdValues[i], peerUserIdValues[i]]);
    }

    return deleteAllByIndexSync(r'owner_id_peer_id', values);
  }

  Future<Id> putByOwnerUserIdPeerUserId(ChatRouteCacheEntity object) {
    return putByIndex(r'owner_id_peer_id', object);
  }

  Id putByOwnerUserIdPeerUserIdSync(
    ChatRouteCacheEntity object, {
    bool saveLinks = true,
  }) {
    return putByIndexSync(r'owner_id_peer_id', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByOwnerUserIdPeerUserId(
    List<ChatRouteCacheEntity> objects,
  ) {
    return putAllByIndex(r'owner_id_peer_id', objects);
  }

  List<Id> putAllByOwnerUserIdPeerUserIdSync(
    List<ChatRouteCacheEntity> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(
      r'owner_id_peer_id',
      objects,
      saveLinks: saveLinks,
    );
  }
}

extension ChatRouteCacheEntityQueryWhereSort
    on QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QWhere> {
  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterWhere>
  anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ChatRouteCacheEntityQueryWhere
    on QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QWhereClause> {
  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterWhereClause>
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterWhereClause>
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

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterWhereClause>
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

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterWhereClause>
  ownerUserIdEqualToAnyPeerUserId(String ownerUserId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'owner_id_peer_id',
          value: [ownerUserId],
        ),
      );
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterWhereClause>
  ownerUserIdNotEqualToAnyPeerUserId(String ownerUserId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_peer_id',
                lower: [],
                upper: [ownerUserId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_peer_id',
                lower: [ownerUserId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_peer_id',
                lower: [ownerUserId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_peer_id',
                lower: [],
                upper: [ownerUserId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterWhereClause>
  ownerUserIdPeerUserIdEqualTo(String ownerUserId, String peerUserId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'owner_id_peer_id',
          value: [ownerUserId, peerUserId],
        ),
      );
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterWhereClause>
  ownerUserIdEqualToPeerUserIdNotEqualTo(
    String ownerUserId,
    String peerUserId,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_peer_id',
                lower: [ownerUserId],
                upper: [ownerUserId, peerUserId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_peer_id',
                lower: [ownerUserId, peerUserId],
                includeLower: false,
                upper: [ownerUserId],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_peer_id',
                lower: [ownerUserId, peerUserId],
                includeLower: false,
                upper: [ownerUserId],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_peer_id',
                lower: [ownerUserId],
                upper: [ownerUserId, peerUserId],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension ChatRouteCacheEntityQueryFilter
    on
        QueryBuilder<
          ChatRouteCacheEntity,
          ChatRouteCacheEntity,
          QFilterCondition
        > {
  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  createdAtMillisEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'created_at', value: value),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  createdAtMillisGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'created_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  createdAtMillisLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'created_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  createdAtMillisBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'created_at',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  deviceIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'device_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  deviceIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'device_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  deviceIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'device_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  deviceIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'device_id',
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
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  deviceIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'device_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  deviceIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'device_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  deviceIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'device_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  deviceIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'device_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  deviceIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'device_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  deviceIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'device_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
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
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
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
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
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
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
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
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  nearbyPeerHintIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'nearby_hint'),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  nearbyPeerHintIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'nearby_hint'),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  nearbyPeerHintEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'nearby_hint',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  nearbyPeerHintGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'nearby_hint',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  nearbyPeerHintLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'nearby_hint',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  nearbyPeerHintBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'nearby_hint',
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
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  nearbyPeerHintStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'nearby_hint',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  nearbyPeerHintEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'nearby_hint',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  nearbyPeerHintContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'nearby_hint',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  nearbyPeerHintMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'nearby_hint',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  nearbyPeerHintIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'nearby_hint', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  nearbyPeerHintIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'nearby_hint', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  ownerUserIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  ownerUserIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  ownerUserIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  ownerUserIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'owner_id',
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
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  ownerUserIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  ownerUserIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  ownerUserIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  ownerUserIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'owner_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  ownerUserIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'owner_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  ownerUserIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'owner_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  peerUserIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'peer_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  peerUserIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'peer_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  peerUserIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'peer_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  peerUserIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'peer_id',
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
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  peerUserIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'peer_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  peerUserIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'peer_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  peerUserIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'peer_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  peerUserIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'peer_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  peerUserIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'peer_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  peerUserIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'peer_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  routeDisplayNameEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'route_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  routeDisplayNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'route_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  routeDisplayNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'route_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  routeDisplayNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'route_name',
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
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  routeDisplayNameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'route_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  routeDisplayNameEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'route_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  routeDisplayNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'route_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  routeDisplayNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'route_name',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  routeDisplayNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'route_name', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  routeDisplayNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'route_name', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  noteIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'route_note'),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  noteIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'route_note'),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  noteEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'route_note',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  noteGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'route_note',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  noteLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'route_note',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  noteBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'route_note',
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
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  noteStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'route_note',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  noteEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'route_note',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  noteContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'route_note',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  noteMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'route_note',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  noteIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'route_note', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  noteIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'route_note', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  safetyNumberEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'safety_number',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  safetyNumberGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'safety_number',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  safetyNumberLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'safety_number',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  safetyNumberBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'safety_number',
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
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  safetyNumberStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'safety_number',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  safetyNumberEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'safety_number',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  safetyNumberContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'safety_number',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  safetyNumberMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'safety_number',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  safetyNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'safety_number', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  safetyNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'safety_number', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  updatedAtMillisEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'updated_at', value: value),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  updatedAtMillisGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'updated_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  updatedAtMillisLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'updated_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ChatRouteCacheEntity,
    ChatRouteCacheEntity,
    QAfterFilterCondition
  >
  updatedAtMillisBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'updated_at',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension ChatRouteCacheEntityQueryObject
    on
        QueryBuilder<
          ChatRouteCacheEntity,
          ChatRouteCacheEntity,
          QFilterCondition
        > {}

extension ChatRouteCacheEntityQueryLinks
    on
        QueryBuilder<
          ChatRouteCacheEntity,
          ChatRouteCacheEntity,
          QFilterCondition
        > {}

extension ChatRouteCacheEntityQuerySortBy
    on QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QSortBy> {
  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
  sortByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created_at', Sort.asc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
  sortByCreatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created_at', Sort.desc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
  sortByDeviceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'device_id', Sort.asc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
  sortByDeviceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'device_id', Sort.desc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
  sortByNearbyPeerHint() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nearby_hint', Sort.asc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
  sortByNearbyPeerHintDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nearby_hint', Sort.desc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
  sortByOwnerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'owner_id', Sort.asc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
  sortByOwnerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'owner_id', Sort.desc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
  sortByPeerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'peer_id', Sort.asc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
  sortByPeerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'peer_id', Sort.desc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
  sortByRouteDisplayName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'route_name', Sort.asc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
  sortByRouteDisplayNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'route_name', Sort.desc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
  sortByNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'route_note', Sort.asc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
  sortByNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'route_note', Sort.desc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
  sortBySafetyNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'safety_number', Sort.asc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
  sortBySafetyNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'safety_number', Sort.desc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
  sortByUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updated_at', Sort.asc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
  sortByUpdatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updated_at', Sort.desc);
    });
  }
}

extension ChatRouteCacheEntityQuerySortThenBy
    on QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QSortThenBy> {
  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
  thenByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created_at', Sort.asc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
  thenByCreatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created_at', Sort.desc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
  thenByDeviceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'device_id', Sort.asc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
  thenByDeviceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'device_id', Sort.desc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
  thenByNearbyPeerHint() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nearby_hint', Sort.asc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
  thenByNearbyPeerHintDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nearby_hint', Sort.desc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
  thenByOwnerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'owner_id', Sort.asc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
  thenByOwnerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'owner_id', Sort.desc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
  thenByPeerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'peer_id', Sort.asc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
  thenByPeerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'peer_id', Sort.desc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
  thenByRouteDisplayName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'route_name', Sort.asc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
  thenByRouteDisplayNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'route_name', Sort.desc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
  thenByNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'route_note', Sort.asc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
  thenByNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'route_note', Sort.desc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
  thenBySafetyNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'safety_number', Sort.asc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
  thenBySafetyNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'safety_number', Sort.desc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
  thenByUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updated_at', Sort.asc);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QAfterSortBy>
  thenByUpdatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updated_at', Sort.desc);
    });
  }
}

extension ChatRouteCacheEntityQueryWhereDistinct
    on QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QDistinct> {
  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QDistinct>
  distinctByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'created_at');
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QDistinct>
  distinctByDeviceId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'device_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QDistinct>
  distinctByNearbyPeerHint({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'nearby_hint', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QDistinct>
  distinctByOwnerUserId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'owner_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QDistinct>
  distinctByPeerUserId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'peer_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QDistinct>
  distinctByRouteDisplayName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'route_name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QDistinct>
  distinctByNote({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'route_note', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QDistinct>
  distinctBySafetyNumber({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'safety_number',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<ChatRouteCacheEntity, ChatRouteCacheEntity, QDistinct>
  distinctByUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updated_at');
    });
  }
}

extension ChatRouteCacheEntityQueryProperty
    on
        QueryBuilder<
          ChatRouteCacheEntity,
          ChatRouteCacheEntity,
          QQueryProperty
        > {
  QueryBuilder<ChatRouteCacheEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ChatRouteCacheEntity, int, QQueryOperations>
  createdAtMillisProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'created_at');
    });
  }

  QueryBuilder<ChatRouteCacheEntity, String, QQueryOperations>
  deviceIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'device_id');
    });
  }

  QueryBuilder<ChatRouteCacheEntity, String?, QQueryOperations>
  nearbyPeerHintProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'nearby_hint');
    });
  }

  QueryBuilder<ChatRouteCacheEntity, String, QQueryOperations>
  ownerUserIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'owner_id');
    });
  }

  QueryBuilder<ChatRouteCacheEntity, String, QQueryOperations>
  peerUserIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'peer_id');
    });
  }

  QueryBuilder<ChatRouteCacheEntity, String, QQueryOperations>
  routeDisplayNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'route_name');
    });
  }

  QueryBuilder<ChatRouteCacheEntity, String?, QQueryOperations> noteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'route_note');
    });
  }

  QueryBuilder<ChatRouteCacheEntity, String, QQueryOperations>
  safetyNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'safety_number');
    });
  }

  QueryBuilder<ChatRouteCacheEntity, int, QQueryOperations>
  updatedAtMillisProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updated_at');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetChatGroupEntityCollection on Isar {
  IsarCollection<ChatGroupEntity> get chatGroupEntitys => this.collection();
}

const ChatGroupEntitySchema = CollectionSchema(
  name: r'group',
  id: -7980787437430964260,
  properties: {
    r'creator_id': PropertySchema(
      id: 0,
      name: r'creator_id',
      type: IsarType.string,
    ),
    r'group_epoch': PropertySchema(
      id: 1,
      name: r'group_epoch',
      type: IsarType.long,
    ),
    r'group_id': PropertySchema(
      id: 2,
      name: r'group_id',
      type: IsarType.string,
    ),
    r'group_name': PropertySchema(
      id: 3,
      name: r'group_name',
      type: IsarType.string,
    ),
    r'has_left': PropertySchema(id: 4, name: r'has_left', type: IsarType.bool),
    r'owner_id': PropertySchema(
      id: 5,
      name: r'owner_id',
      type: IsarType.string,
    ),
  },

  estimateSize: _chatGroupEntityEstimateSize,
  serialize: _chatGroupEntitySerialize,
  deserialize: _chatGroupEntityDeserialize,
  deserializeProp: _chatGroupEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'owner_id_group_id': IndexSchema(
      id: -427454306745948833,
      name: r'owner_id_group_id',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'owner_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'group_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _chatGroupEntityGetId,
  getLinks: _chatGroupEntityGetLinks,
  attach: _chatGroupEntityAttach,
  version: '3.3.2',
);

int _chatGroupEntityEstimateSize(
  ChatGroupEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.creatorUserId.length * 3;
  bytesCount += 3 + object.groupId.length * 3;
  bytesCount += 3 + object.groupName.length * 3;
  bytesCount += 3 + object.ownerUserId.length * 3;
  return bytesCount;
}

void _chatGroupEntitySerialize(
  ChatGroupEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.creatorUserId);
  writer.writeLong(offsets[1], object.epoch);
  writer.writeString(offsets[2], object.groupId);
  writer.writeString(offsets[3], object.groupName);
  writer.writeBool(offsets[4], object.leftLocally);
  writer.writeString(offsets[5], object.ownerUserId);
}

ChatGroupEntity _chatGroupEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ChatGroupEntity();
  object.creatorUserId = reader.readString(offsets[0]);
  object.epoch = reader.readLong(offsets[1]);
  object.groupId = reader.readString(offsets[2]);
  object.groupName = reader.readString(offsets[3]);
  object.leftLocally = reader.readBool(offsets[4]);
  object.id = id;
  object.ownerUserId = reader.readString(offsets[5]);
  return object;
}

P _chatGroupEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readBool(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _chatGroupEntityGetId(ChatGroupEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _chatGroupEntityGetLinks(ChatGroupEntity object) {
  return [];
}

void _chatGroupEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  ChatGroupEntity object,
) {
  object.id = id;
}

extension ChatGroupEntityByIndex on IsarCollection<ChatGroupEntity> {
  Future<ChatGroupEntity?> getByOwnerUserIdGroupId(
    String ownerUserId,
    String groupId,
  ) {
    return getByIndex(r'owner_id_group_id', [ownerUserId, groupId]);
  }

  ChatGroupEntity? getByOwnerUserIdGroupIdSync(
    String ownerUserId,
    String groupId,
  ) {
    return getByIndexSync(r'owner_id_group_id', [ownerUserId, groupId]);
  }

  Future<bool> deleteByOwnerUserIdGroupId(String ownerUserId, String groupId) {
    return deleteByIndex(r'owner_id_group_id', [ownerUserId, groupId]);
  }

  bool deleteByOwnerUserIdGroupIdSync(String ownerUserId, String groupId) {
    return deleteByIndexSync(r'owner_id_group_id', [ownerUserId, groupId]);
  }

  Future<List<ChatGroupEntity?>> getAllByOwnerUserIdGroupId(
    List<String> ownerUserIdValues,
    List<String> groupIdValues,
  ) {
    final len = ownerUserIdValues.length;
    assert(
      groupIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerUserIdValues[i], groupIdValues[i]]);
    }

    return getAllByIndex(r'owner_id_group_id', values);
  }

  List<ChatGroupEntity?> getAllByOwnerUserIdGroupIdSync(
    List<String> ownerUserIdValues,
    List<String> groupIdValues,
  ) {
    final len = ownerUserIdValues.length;
    assert(
      groupIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerUserIdValues[i], groupIdValues[i]]);
    }

    return getAllByIndexSync(r'owner_id_group_id', values);
  }

  Future<int> deleteAllByOwnerUserIdGroupId(
    List<String> ownerUserIdValues,
    List<String> groupIdValues,
  ) {
    final len = ownerUserIdValues.length;
    assert(
      groupIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerUserIdValues[i], groupIdValues[i]]);
    }

    return deleteAllByIndex(r'owner_id_group_id', values);
  }

  int deleteAllByOwnerUserIdGroupIdSync(
    List<String> ownerUserIdValues,
    List<String> groupIdValues,
  ) {
    final len = ownerUserIdValues.length;
    assert(
      groupIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerUserIdValues[i], groupIdValues[i]]);
    }

    return deleteAllByIndexSync(r'owner_id_group_id', values);
  }

  Future<Id> putByOwnerUserIdGroupId(ChatGroupEntity object) {
    return putByIndex(r'owner_id_group_id', object);
  }

  Id putByOwnerUserIdGroupIdSync(
    ChatGroupEntity object, {
    bool saveLinks = true,
  }) {
    return putByIndexSync(r'owner_id_group_id', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByOwnerUserIdGroupId(List<ChatGroupEntity> objects) {
    return putAllByIndex(r'owner_id_group_id', objects);
  }

  List<Id> putAllByOwnerUserIdGroupIdSync(
    List<ChatGroupEntity> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(
      r'owner_id_group_id',
      objects,
      saveLinks: saveLinks,
    );
  }
}

extension ChatGroupEntityQueryWhereSort
    on QueryBuilder<ChatGroupEntity, ChatGroupEntity, QWhere> {
  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ChatGroupEntityQueryWhere
    on QueryBuilder<ChatGroupEntity, ChatGroupEntity, QWhereClause> {
  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterWhereClause>
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

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterWhereClause> idBetween(
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

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterWhereClause>
  ownerUserIdEqualToAnyGroupId(String ownerUserId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'owner_id_group_id',
          value: [ownerUserId],
        ),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterWhereClause>
  ownerUserIdNotEqualToAnyGroupId(String ownerUserId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_group_id',
                lower: [],
                upper: [ownerUserId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_group_id',
                lower: [ownerUserId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_group_id',
                lower: [ownerUserId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_group_id',
                lower: [],
                upper: [ownerUserId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterWhereClause>
  ownerUserIdGroupIdEqualTo(String ownerUserId, String groupId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'owner_id_group_id',
          value: [ownerUserId, groupId],
        ),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterWhereClause>
  ownerUserIdEqualToGroupIdNotEqualTo(String ownerUserId, String groupId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_group_id',
                lower: [ownerUserId],
                upper: [ownerUserId, groupId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_group_id',
                lower: [ownerUserId, groupId],
                includeLower: false,
                upper: [ownerUserId],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_group_id',
                lower: [ownerUserId, groupId],
                includeLower: false,
                upper: [ownerUserId],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_group_id',
                lower: [ownerUserId],
                upper: [ownerUserId, groupId],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension ChatGroupEntityQueryFilter
    on QueryBuilder<ChatGroupEntity, ChatGroupEntity, QFilterCondition> {
  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  creatorUserIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'creator_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  creatorUserIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'creator_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  creatorUserIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'creator_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  creatorUserIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'creator_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  creatorUserIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'creator_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  creatorUserIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'creator_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  creatorUserIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'creator_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  creatorUserIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'creator_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  creatorUserIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'creator_id', value: ''),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  creatorUserIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'creator_id', value: ''),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  epochEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'group_epoch', value: value),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  epochGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'group_epoch',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  epochLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'group_epoch',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  epochBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'group_epoch',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  groupIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'group_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  groupIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'group_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  groupIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'group_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  groupIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'group_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  groupIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'group_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  groupIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'group_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  groupIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'group_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  groupIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'group_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  groupIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'group_id', value: ''),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  groupIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'group_id', value: ''),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  groupNameEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'group_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  groupNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'group_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  groupNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'group_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  groupNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'group_name',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  groupNameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'group_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  groupNameEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'group_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  groupNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'group_name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  groupNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'group_name',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  groupNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'group_name', value: ''),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  groupNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'group_name', value: ''),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  leftLocallyEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'has_left', value: value),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
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

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
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

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
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

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  ownerUserIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  ownerUserIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  ownerUserIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  ownerUserIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'owner_id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  ownerUserIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  ownerUserIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  ownerUserIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  ownerUserIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'owner_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  ownerUserIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'owner_id', value: ''),
      );
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterFilterCondition>
  ownerUserIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'owner_id', value: ''),
      );
    });
  }
}

extension ChatGroupEntityQueryObject
    on QueryBuilder<ChatGroupEntity, ChatGroupEntity, QFilterCondition> {}

extension ChatGroupEntityQueryLinks
    on QueryBuilder<ChatGroupEntity, ChatGroupEntity, QFilterCondition> {}

extension ChatGroupEntityQuerySortBy
    on QueryBuilder<ChatGroupEntity, ChatGroupEntity, QSortBy> {
  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
  sortByCreatorUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'creator_id', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
  sortByCreatorUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'creator_id', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy> sortByEpoch() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'group_epoch', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
  sortByEpochDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'group_epoch', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy> sortByGroupId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'group_id', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
  sortByGroupIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'group_id', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
  sortByGroupName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'group_name', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
  sortByGroupNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'group_name', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
  sortByLeftLocally() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'has_left', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
  sortByLeftLocallyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'has_left', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
  sortByOwnerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'owner_id', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
  sortByOwnerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'owner_id', Sort.desc);
    });
  }
}

extension ChatGroupEntityQuerySortThenBy
    on QueryBuilder<ChatGroupEntity, ChatGroupEntity, QSortThenBy> {
  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
  thenByCreatorUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'creator_id', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
  thenByCreatorUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'creator_id', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy> thenByEpoch() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'group_epoch', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
  thenByEpochDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'group_epoch', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy> thenByGroupId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'group_id', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
  thenByGroupIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'group_id', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
  thenByGroupName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'group_name', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
  thenByGroupNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'group_name', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
  thenByLeftLocally() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'has_left', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
  thenByLeftLocallyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'has_left', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
  thenByOwnerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'owner_id', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QAfterSortBy>
  thenByOwnerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'owner_id', Sort.desc);
    });
  }
}

extension ChatGroupEntityQueryWhereDistinct
    on QueryBuilder<ChatGroupEntity, ChatGroupEntity, QDistinct> {
  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QDistinct>
  distinctByCreatorUserId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'creator_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QDistinct> distinctByEpoch() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'group_epoch');
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QDistinct> distinctByGroupId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'group_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QDistinct>
  distinctByGroupName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'group_name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QDistinct>
  distinctByLeftLocally() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'has_left');
    });
  }

  QueryBuilder<ChatGroupEntity, ChatGroupEntity, QDistinct>
  distinctByOwnerUserId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'owner_id', caseSensitive: caseSensitive);
    });
  }
}

extension ChatGroupEntityQueryProperty
    on QueryBuilder<ChatGroupEntity, ChatGroupEntity, QQueryProperty> {
  QueryBuilder<ChatGroupEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ChatGroupEntity, String, QQueryOperations>
  creatorUserIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'creator_id');
    });
  }

  QueryBuilder<ChatGroupEntity, int, QQueryOperations> epochProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'group_epoch');
    });
  }

  QueryBuilder<ChatGroupEntity, String, QQueryOperations> groupIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'group_id');
    });
  }

  QueryBuilder<ChatGroupEntity, String, QQueryOperations> groupNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'group_name');
    });
  }

  QueryBuilder<ChatGroupEntity, bool, QQueryOperations> leftLocallyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'has_left');
    });
  }

  QueryBuilder<ChatGroupEntity, String, QQueryOperations>
  ownerUserIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'owner_id');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetChatGroupMemberEntityCollection on Isar {
  IsarCollection<ChatGroupMemberEntity> get chatGroupMemberEntitys =>
      this.collection();
}

const ChatGroupMemberEntitySchema = CollectionSchema(
  name: r'member',
  id: 4005898307651635317,
  properties: {
    r'group_id': PropertySchema(
      id: 0,
      name: r'group_id',
      type: IsarType.string,
    ),
    r'member_id': PropertySchema(
      id: 1,
      name: r'member_id',
      type: IsarType.string,
    ),
    r'member_role': PropertySchema(
      id: 2,
      name: r'member_role',
      type: IsarType.string,
    ),
    r'owner_id': PropertySchema(
      id: 3,
      name: r'owner_id',
      type: IsarType.string,
    ),
  },

  estimateSize: _chatGroupMemberEntityEstimateSize,
  serialize: _chatGroupMemberEntitySerialize,
  deserialize: _chatGroupMemberEntityDeserialize,
  deserializeProp: _chatGroupMemberEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'owner_id_group_id_member_id': IndexSchema(
      id: 1960610877781981911,
      name: r'owner_id_group_id_member_id',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'owner_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'group_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'member_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'group_id': IndexSchema(
      id: 8896262069560657725,
      name: r'group_id',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'group_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _chatGroupMemberEntityGetId,
  getLinks: _chatGroupMemberEntityGetLinks,
  attach: _chatGroupMemberEntityAttach,
  version: '3.3.2',
);

int _chatGroupMemberEntityEstimateSize(
  ChatGroupMemberEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.groupId.length * 3;
  bytesCount += 3 + object.memberUserId.length * 3;
  bytesCount += 3 + object.role.length * 3;
  bytesCount += 3 + object.ownerUserId.length * 3;
  return bytesCount;
}

void _chatGroupMemberEntitySerialize(
  ChatGroupMemberEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.groupId);
  writer.writeString(offsets[1], object.memberUserId);
  writer.writeString(offsets[2], object.role);
  writer.writeString(offsets[3], object.ownerUserId);
}

ChatGroupMemberEntity _chatGroupMemberEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ChatGroupMemberEntity();
  object.groupId = reader.readString(offsets[0]);
  object.id = id;
  object.memberUserId = reader.readString(offsets[1]);
  object.role = reader.readString(offsets[2]);
  object.ownerUserId = reader.readString(offsets[3]);
  return object;
}

P _chatGroupMemberEntityDeserializeProp<P>(
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
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _chatGroupMemberEntityGetId(ChatGroupMemberEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _chatGroupMemberEntityGetLinks(
  ChatGroupMemberEntity object,
) {
  return [];
}

void _chatGroupMemberEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  ChatGroupMemberEntity object,
) {
  object.id = id;
}

extension ChatGroupMemberEntityByIndex
    on IsarCollection<ChatGroupMemberEntity> {
  Future<ChatGroupMemberEntity?> getByOwnerUserIdGroupIdMemberUserId(
    String ownerUserId,
    String groupId,
    String memberUserId,
  ) {
    return getByIndex(r'owner_id_group_id_member_id', [
      ownerUserId,
      groupId,
      memberUserId,
    ]);
  }

  ChatGroupMemberEntity? getByOwnerUserIdGroupIdMemberUserIdSync(
    String ownerUserId,
    String groupId,
    String memberUserId,
  ) {
    return getByIndexSync(r'owner_id_group_id_member_id', [
      ownerUserId,
      groupId,
      memberUserId,
    ]);
  }

  Future<bool> deleteByOwnerUserIdGroupIdMemberUserId(
    String ownerUserId,
    String groupId,
    String memberUserId,
  ) {
    return deleteByIndex(r'owner_id_group_id_member_id', [
      ownerUserId,
      groupId,
      memberUserId,
    ]);
  }

  bool deleteByOwnerUserIdGroupIdMemberUserIdSync(
    String ownerUserId,
    String groupId,
    String memberUserId,
  ) {
    return deleteByIndexSync(r'owner_id_group_id_member_id', [
      ownerUserId,
      groupId,
      memberUserId,
    ]);
  }

  Future<List<ChatGroupMemberEntity?>> getAllByOwnerUserIdGroupIdMemberUserId(
    List<String> ownerUserIdValues,
    List<String> groupIdValues,
    List<String> memberUserIdValues,
  ) {
    final len = ownerUserIdValues.length;
    assert(
      groupIdValues.length == len && memberUserIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([
        ownerUserIdValues[i],
        groupIdValues[i],
        memberUserIdValues[i],
      ]);
    }

    return getAllByIndex(r'owner_id_group_id_member_id', values);
  }

  List<ChatGroupMemberEntity?> getAllByOwnerUserIdGroupIdMemberUserIdSync(
    List<String> ownerUserIdValues,
    List<String> groupIdValues,
    List<String> memberUserIdValues,
  ) {
    final len = ownerUserIdValues.length;
    assert(
      groupIdValues.length == len && memberUserIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([
        ownerUserIdValues[i],
        groupIdValues[i],
        memberUserIdValues[i],
      ]);
    }

    return getAllByIndexSync(r'owner_id_group_id_member_id', values);
  }

  Future<int> deleteAllByOwnerUserIdGroupIdMemberUserId(
    List<String> ownerUserIdValues,
    List<String> groupIdValues,
    List<String> memberUserIdValues,
  ) {
    final len = ownerUserIdValues.length;
    assert(
      groupIdValues.length == len && memberUserIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([
        ownerUserIdValues[i],
        groupIdValues[i],
        memberUserIdValues[i],
      ]);
    }

    return deleteAllByIndex(r'owner_id_group_id_member_id', values);
  }

  int deleteAllByOwnerUserIdGroupIdMemberUserIdSync(
    List<String> ownerUserIdValues,
    List<String> groupIdValues,
    List<String> memberUserIdValues,
  ) {
    final len = ownerUserIdValues.length;
    assert(
      groupIdValues.length == len && memberUserIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([
        ownerUserIdValues[i],
        groupIdValues[i],
        memberUserIdValues[i],
      ]);
    }

    return deleteAllByIndexSync(r'owner_id_group_id_member_id', values);
  }

  Future<Id> putByOwnerUserIdGroupIdMemberUserId(ChatGroupMemberEntity object) {
    return putByIndex(r'owner_id_group_id_member_id', object);
  }

  Id putByOwnerUserIdGroupIdMemberUserIdSync(
    ChatGroupMemberEntity object, {
    bool saveLinks = true,
  }) {
    return putByIndexSync(
      r'owner_id_group_id_member_id',
      object,
      saveLinks: saveLinks,
    );
  }

  Future<List<Id>> putAllByOwnerUserIdGroupIdMemberUserId(
    List<ChatGroupMemberEntity> objects,
  ) {
    return putAllByIndex(r'owner_id_group_id_member_id', objects);
  }

  List<Id> putAllByOwnerUserIdGroupIdMemberUserIdSync(
    List<ChatGroupMemberEntity> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(
      r'owner_id_group_id_member_id',
      objects,
      saveLinks: saveLinks,
    );
  }
}

extension ChatGroupMemberEntityQueryWhereSort
    on QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QWhere> {
  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterWhere>
  anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ChatGroupMemberEntityQueryWhere
    on
        QueryBuilder<
          ChatGroupMemberEntity,
          ChatGroupMemberEntity,
          QWhereClause
        > {
  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterWhereClause>
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterWhereClause>
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

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterWhereClause>
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

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterWhereClause>
  ownerUserIdEqualToAnyGroupIdMemberUserId(String ownerUserId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'owner_id_group_id_member_id',
          value: [ownerUserId],
        ),
      );
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterWhereClause>
  ownerUserIdNotEqualToAnyGroupIdMemberUserId(String ownerUserId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_group_id_member_id',
                lower: [],
                upper: [ownerUserId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_group_id_member_id',
                lower: [ownerUserId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_group_id_member_id',
                lower: [ownerUserId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_group_id_member_id',
                lower: [],
                upper: [ownerUserId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterWhereClause>
  ownerUserIdGroupIdEqualToAnyMemberUserId(String ownerUserId, String groupId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'owner_id_group_id_member_id',
          value: [ownerUserId, groupId],
        ),
      );
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterWhereClause>
  ownerUserIdEqualToGroupIdNotEqualToAnyMemberUserId(
    String ownerUserId,
    String groupId,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_group_id_member_id',
                lower: [ownerUserId],
                upper: [ownerUserId, groupId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_group_id_member_id',
                lower: [ownerUserId, groupId],
                includeLower: false,
                upper: [ownerUserId],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_group_id_member_id',
                lower: [ownerUserId, groupId],
                includeLower: false,
                upper: [ownerUserId],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_group_id_member_id',
                lower: [ownerUserId],
                upper: [ownerUserId, groupId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterWhereClause>
  ownerUserIdGroupIdMemberUserIdEqualTo(
    String ownerUserId,
    String groupId,
    String memberUserId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'owner_id_group_id_member_id',
          value: [ownerUserId, groupId, memberUserId],
        ),
      );
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterWhereClause>
  ownerUserIdGroupIdEqualToMemberUserIdNotEqualTo(
    String ownerUserId,
    String groupId,
    String memberUserId,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_group_id_member_id',
                lower: [ownerUserId, groupId],
                upper: [ownerUserId, groupId, memberUserId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_group_id_member_id',
                lower: [ownerUserId, groupId, memberUserId],
                includeLower: false,
                upper: [ownerUserId, groupId],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_group_id_member_id',
                lower: [ownerUserId, groupId, memberUserId],
                includeLower: false,
                upper: [ownerUserId, groupId],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_group_id_member_id',
                lower: [ownerUserId, groupId],
                upper: [ownerUserId, groupId, memberUserId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterWhereClause>
  groupIdEqualTo(String groupId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'group_id', value: [groupId]),
      );
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterWhereClause>
  groupIdNotEqualTo(String groupId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'group_id',
                lower: [],
                upper: [groupId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'group_id',
                lower: [groupId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'group_id',
                lower: [groupId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'group_id',
                lower: [],
                upper: [groupId],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension ChatGroupMemberEntityQueryFilter
    on
        QueryBuilder<
          ChatGroupMemberEntity,
          ChatGroupMemberEntity,
          QFilterCondition
        > {
  QueryBuilder<
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
    QAfterFilterCondition
  >
  groupIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'group_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
    QAfterFilterCondition
  >
  groupIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'group_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
    QAfterFilterCondition
  >
  groupIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'group_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
    QAfterFilterCondition
  >
  groupIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'group_id',
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
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
    QAfterFilterCondition
  >
  groupIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'group_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
    QAfterFilterCondition
  >
  groupIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'group_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
    QAfterFilterCondition
  >
  groupIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'group_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
    QAfterFilterCondition
  >
  groupIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'group_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
    QAfterFilterCondition
  >
  groupIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'group_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
    QAfterFilterCondition
  >
  groupIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'group_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
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
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
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
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
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
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
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
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
    QAfterFilterCondition
  >
  memberUserIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'member_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
    QAfterFilterCondition
  >
  memberUserIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'member_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
    QAfterFilterCondition
  >
  memberUserIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'member_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
    QAfterFilterCondition
  >
  memberUserIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'member_id',
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
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
    QAfterFilterCondition
  >
  memberUserIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'member_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
    QAfterFilterCondition
  >
  memberUserIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'member_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
    QAfterFilterCondition
  >
  memberUserIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'member_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
    QAfterFilterCondition
  >
  memberUserIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'member_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
    QAfterFilterCondition
  >
  memberUserIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'member_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
    QAfterFilterCondition
  >
  memberUserIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'member_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
    QAfterFilterCondition
  >
  roleEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'member_role',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
    QAfterFilterCondition
  >
  roleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'member_role',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
    QAfterFilterCondition
  >
  roleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'member_role',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
    QAfterFilterCondition
  >
  roleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'member_role',
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
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
    QAfterFilterCondition
  >
  roleStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'member_role',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
    QAfterFilterCondition
  >
  roleEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'member_role',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
    QAfterFilterCondition
  >
  roleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'member_role',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
    QAfterFilterCondition
  >
  roleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'member_role',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
    QAfterFilterCondition
  >
  roleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'member_role', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
    QAfterFilterCondition
  >
  roleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'member_role', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
    QAfterFilterCondition
  >
  ownerUserIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
    QAfterFilterCondition
  >
  ownerUserIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
    QAfterFilterCondition
  >
  ownerUserIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
    QAfterFilterCondition
  >
  ownerUserIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'owner_id',
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
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
    QAfterFilterCondition
  >
  ownerUserIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
    QAfterFilterCondition
  >
  ownerUserIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
    QAfterFilterCondition
  >
  ownerUserIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
    QAfterFilterCondition
  >
  ownerUserIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'owner_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
    QAfterFilterCondition
  >
  ownerUserIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'owner_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatGroupMemberEntity,
    ChatGroupMemberEntity,
    QAfterFilterCondition
  >
  ownerUserIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'owner_id', value: ''),
      );
    });
  }
}

extension ChatGroupMemberEntityQueryObject
    on
        QueryBuilder<
          ChatGroupMemberEntity,
          ChatGroupMemberEntity,
          QFilterCondition
        > {}

extension ChatGroupMemberEntityQueryLinks
    on
        QueryBuilder<
          ChatGroupMemberEntity,
          ChatGroupMemberEntity,
          QFilterCondition
        > {}

extension ChatGroupMemberEntityQuerySortBy
    on QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QSortBy> {
  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
  sortByGroupId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'group_id', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
  sortByGroupIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'group_id', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
  sortByMemberUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'member_id', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
  sortByMemberUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'member_id', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
  sortByRole() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'member_role', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
  sortByRoleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'member_role', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
  sortByOwnerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'owner_id', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
  sortByOwnerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'owner_id', Sort.desc);
    });
  }
}

extension ChatGroupMemberEntityQuerySortThenBy
    on QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QSortThenBy> {
  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
  thenByGroupId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'group_id', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
  thenByGroupIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'group_id', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
  thenByMemberUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'member_id', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
  thenByMemberUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'member_id', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
  thenByRole() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'member_role', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
  thenByRoleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'member_role', Sort.desc);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
  thenByOwnerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'owner_id', Sort.asc);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QAfterSortBy>
  thenByOwnerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'owner_id', Sort.desc);
    });
  }
}

extension ChatGroupMemberEntityQueryWhereDistinct
    on QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QDistinct> {
  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QDistinct>
  distinctByGroupId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'group_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QDistinct>
  distinctByMemberUserId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'member_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QDistinct>
  distinctByRole({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'member_role', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatGroupMemberEntity, ChatGroupMemberEntity, QDistinct>
  distinctByOwnerUserId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'owner_id', caseSensitive: caseSensitive);
    });
  }
}

extension ChatGroupMemberEntityQueryProperty
    on
        QueryBuilder<
          ChatGroupMemberEntity,
          ChatGroupMemberEntity,
          QQueryProperty
        > {
  QueryBuilder<ChatGroupMemberEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ChatGroupMemberEntity, String, QQueryOperations>
  groupIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'group_id');
    });
  }

  QueryBuilder<ChatGroupMemberEntity, String, QQueryOperations>
  memberUserIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'member_id');
    });
  }

  QueryBuilder<ChatGroupMemberEntity, String, QQueryOperations> roleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'member_role');
    });
  }

  QueryBuilder<ChatGroupMemberEntity, String, QQueryOperations>
  ownerUserIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'owner_id');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetChatGroupPendingCommitEntityCollection on Isar {
  IsarCollection<ChatGroupPendingCommitEntity>
  get chatGroupPendingCommitEntitys => this.collection();
}

const ChatGroupPendingCommitEntitySchema = CollectionSchema(
  name: r'commit',
  id: -1623704559087056712,
  properties: {
    r'created_at': PropertySchema(
      id: 0,
      name: r'created_at',
      type: IsarType.long,
    ),
    r'group_id': PropertySchema(
      id: 1,
      name: r'group_id',
      type: IsarType.string,
    ),
    r'message_bytes': PropertySchema(
      id: 2,
      name: r'message_bytes',
      type: IsarType.string,
    ),
    r'message_epoch': PropertySchema(
      id: 3,
      name: r'message_epoch',
      type: IsarType.long,
    ),
    r'message_id': PropertySchema(
      id: 4,
      name: r'message_id',
      type: IsarType.string,
    ),
    r'owner_id': PropertySchema(
      id: 5,
      name: r'owner_id',
      type: IsarType.string,
    ),
  },

  estimateSize: _chatGroupPendingCommitEntityEstimateSize,
  serialize: _chatGroupPendingCommitEntitySerialize,
  deserialize: _chatGroupPendingCommitEntityDeserialize,
  deserializeProp: _chatGroupPendingCommitEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'owner_id_message_id': IndexSchema(
      id: -5137609912169235308,
      name: r'owner_id_message_id',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'owner_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'message_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'group_id': IndexSchema(
      id: 8896262069560657725,
      name: r'group_id',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'group_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'message_epoch': IndexSchema(
      id: 6817274195912465953,
      name: r'message_epoch',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'message_epoch',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _chatGroupPendingCommitEntityGetId,
  getLinks: _chatGroupPendingCommitEntityGetLinks,
  attach: _chatGroupPendingCommitEntityAttach,
  version: '3.3.2',
);

int _chatGroupPendingCommitEntityEstimateSize(
  ChatGroupPendingCommitEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.groupId.length * 3;
  bytesCount += 3 + object.messageBytesHex.length * 3;
  bytesCount += 3 + object.messageId.length * 3;
  bytesCount += 3 + object.ownerUserId.length * 3;
  return bytesCount;
}

void _chatGroupPendingCommitEntitySerialize(
  ChatGroupPendingCommitEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.createdAtMillis);
  writer.writeString(offsets[1], object.groupId);
  writer.writeString(offsets[2], object.messageBytesHex);
  writer.writeLong(offsets[3], object.messageEpoch);
  writer.writeString(offsets[4], object.messageId);
  writer.writeString(offsets[5], object.ownerUserId);
}

ChatGroupPendingCommitEntity _chatGroupPendingCommitEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ChatGroupPendingCommitEntity();
  object.createdAtMillis = reader.readLong(offsets[0]);
  object.groupId = reader.readString(offsets[1]);
  object.id = id;
  object.messageBytesHex = reader.readString(offsets[2]);
  object.messageEpoch = reader.readLong(offsets[3]);
  object.messageId = reader.readString(offsets[4]);
  object.ownerUserId = reader.readString(offsets[5]);
  return object;
}

P _chatGroupPendingCommitEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _chatGroupPendingCommitEntityGetId(ChatGroupPendingCommitEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _chatGroupPendingCommitEntityGetLinks(
  ChatGroupPendingCommitEntity object,
) {
  return [];
}

void _chatGroupPendingCommitEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  ChatGroupPendingCommitEntity object,
) {
  object.id = id;
}

extension ChatGroupPendingCommitEntityByIndex
    on IsarCollection<ChatGroupPendingCommitEntity> {
  Future<ChatGroupPendingCommitEntity?> getByOwnerUserIdMessageId(
    String ownerUserId,
    String messageId,
  ) {
    return getByIndex(r'owner_id_message_id', [ownerUserId, messageId]);
  }

  ChatGroupPendingCommitEntity? getByOwnerUserIdMessageIdSync(
    String ownerUserId,
    String messageId,
  ) {
    return getByIndexSync(r'owner_id_message_id', [ownerUserId, messageId]);
  }

  Future<bool> deleteByOwnerUserIdMessageId(
    String ownerUserId,
    String messageId,
  ) {
    return deleteByIndex(r'owner_id_message_id', [ownerUserId, messageId]);
  }

  bool deleteByOwnerUserIdMessageIdSync(String ownerUserId, String messageId) {
    return deleteByIndexSync(r'owner_id_message_id', [ownerUserId, messageId]);
  }

  Future<List<ChatGroupPendingCommitEntity?>> getAllByOwnerUserIdMessageId(
    List<String> ownerUserIdValues,
    List<String> messageIdValues,
  ) {
    final len = ownerUserIdValues.length;
    assert(
      messageIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerUserIdValues[i], messageIdValues[i]]);
    }

    return getAllByIndex(r'owner_id_message_id', values);
  }

  List<ChatGroupPendingCommitEntity?> getAllByOwnerUserIdMessageIdSync(
    List<String> ownerUserIdValues,
    List<String> messageIdValues,
  ) {
    final len = ownerUserIdValues.length;
    assert(
      messageIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerUserIdValues[i], messageIdValues[i]]);
    }

    return getAllByIndexSync(r'owner_id_message_id', values);
  }

  Future<int> deleteAllByOwnerUserIdMessageId(
    List<String> ownerUserIdValues,
    List<String> messageIdValues,
  ) {
    final len = ownerUserIdValues.length;
    assert(
      messageIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerUserIdValues[i], messageIdValues[i]]);
    }

    return deleteAllByIndex(r'owner_id_message_id', values);
  }

  int deleteAllByOwnerUserIdMessageIdSync(
    List<String> ownerUserIdValues,
    List<String> messageIdValues,
  ) {
    final len = ownerUserIdValues.length;
    assert(
      messageIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([ownerUserIdValues[i], messageIdValues[i]]);
    }

    return deleteAllByIndexSync(r'owner_id_message_id', values);
  }

  Future<Id> putByOwnerUserIdMessageId(ChatGroupPendingCommitEntity object) {
    return putByIndex(r'owner_id_message_id', object);
  }

  Id putByOwnerUserIdMessageIdSync(
    ChatGroupPendingCommitEntity object, {
    bool saveLinks = true,
  }) {
    return putByIndexSync(r'owner_id_message_id', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByOwnerUserIdMessageId(
    List<ChatGroupPendingCommitEntity> objects,
  ) {
    return putAllByIndex(r'owner_id_message_id', objects);
  }

  List<Id> putAllByOwnerUserIdMessageIdSync(
    List<ChatGroupPendingCommitEntity> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(
      r'owner_id_message_id',
      objects,
      saveLinks: saveLinks,
    );
  }
}

extension ChatGroupPendingCommitEntityQueryWhereSort
    on
        QueryBuilder<
          ChatGroupPendingCommitEntity,
          ChatGroupPendingCommitEntity,
          QWhere
        > {
  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterWhere
  >
  anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterWhere
  >
  anyMessageEpoch() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'message_epoch'),
      );
    });
  }
}

extension ChatGroupPendingCommitEntityQueryWhere
    on
        QueryBuilder<
          ChatGroupPendingCommitEntity,
          ChatGroupPendingCommitEntity,
          QWhereClause
        > {
  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterWhereClause
  >
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterWhereClause
  >
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

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterWhereClause
  >
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterWhereClause
  >
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterWhereClause
  >
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

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterWhereClause
  >
  ownerUserIdEqualToAnyMessageId(String ownerUserId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'owner_id_message_id',
          value: [ownerUserId],
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterWhereClause
  >
  ownerUserIdNotEqualToAnyMessageId(String ownerUserId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_message_id',
                lower: [],
                upper: [ownerUserId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_message_id',
                lower: [ownerUserId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_message_id',
                lower: [ownerUserId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_message_id',
                lower: [],
                upper: [ownerUserId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterWhereClause
  >
  ownerUserIdMessageIdEqualTo(String ownerUserId, String messageId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'owner_id_message_id',
          value: [ownerUserId, messageId],
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterWhereClause
  >
  ownerUserIdEqualToMessageIdNotEqualTo(String ownerUserId, String messageId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_message_id',
                lower: [ownerUserId],
                upper: [ownerUserId, messageId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_message_id',
                lower: [ownerUserId, messageId],
                includeLower: false,
                upper: [ownerUserId],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_message_id',
                lower: [ownerUserId, messageId],
                includeLower: false,
                upper: [ownerUserId],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id_message_id',
                lower: [ownerUserId],
                upper: [ownerUserId, messageId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterWhereClause
  >
  groupIdEqualTo(String groupId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'group_id', value: [groupId]),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterWhereClause
  >
  groupIdNotEqualTo(String groupId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'group_id',
                lower: [],
                upper: [groupId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'group_id',
                lower: [groupId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'group_id',
                lower: [groupId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'group_id',
                lower: [],
                upper: [groupId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterWhereClause
  >
  messageEpochEqualTo(int messageEpoch) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'message_epoch',
          value: [messageEpoch],
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterWhereClause
  >
  messageEpochNotEqualTo(int messageEpoch) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'message_epoch',
                lower: [],
                upper: [messageEpoch],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'message_epoch',
                lower: [messageEpoch],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'message_epoch',
                lower: [messageEpoch],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'message_epoch',
                lower: [],
                upper: [messageEpoch],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterWhereClause
  >
  messageEpochGreaterThan(int messageEpoch, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'message_epoch',
          lower: [messageEpoch],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterWhereClause
  >
  messageEpochLessThan(int messageEpoch, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'message_epoch',
          lower: [],
          upper: [messageEpoch],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterWhereClause
  >
  messageEpochBetween(
    int lowerMessageEpoch,
    int upperMessageEpoch, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'message_epoch',
          lower: [lowerMessageEpoch],
          includeLower: includeLower,
          upper: [upperMessageEpoch],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension ChatGroupPendingCommitEntityQueryFilter
    on
        QueryBuilder<
          ChatGroupPendingCommitEntity,
          ChatGroupPendingCommitEntity,
          QFilterCondition
        > {
  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  createdAtMillisEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'created_at', value: value),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  createdAtMillisGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'created_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  createdAtMillisLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'created_at',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  createdAtMillisBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'created_at',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  groupIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'group_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  groupIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'group_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  groupIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'group_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  groupIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'group_id',
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
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  groupIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'group_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  groupIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'group_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  groupIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'group_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  groupIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'group_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  groupIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'group_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  groupIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'group_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
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
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
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
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
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
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
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
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  messageBytesHexEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'message_bytes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  messageBytesHexGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'message_bytes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  messageBytesHexLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'message_bytes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  messageBytesHexBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'message_bytes',
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
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  messageBytesHexStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'message_bytes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  messageBytesHexEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'message_bytes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  messageBytesHexContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'message_bytes',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  messageBytesHexMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'message_bytes',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  messageBytesHexIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'message_bytes', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  messageBytesHexIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'message_bytes', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  messageEpochEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'message_epoch', value: value),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  messageEpochGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'message_epoch',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  messageEpochLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'message_epoch',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  messageEpochBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'message_epoch',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  messageIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'message_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  messageIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'message_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  messageIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'message_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  messageIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'message_id',
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
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  messageIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'message_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  messageIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'message_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  messageIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'message_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  messageIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'message_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  messageIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'message_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  messageIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'message_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  ownerUserIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  ownerUserIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  ownerUserIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  ownerUserIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'owner_id',
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
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  ownerUserIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  ownerUserIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  ownerUserIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  ownerUserIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'owner_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  ownerUserIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'owner_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterFilterCondition
  >
  ownerUserIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'owner_id', value: ''),
      );
    });
  }
}

extension ChatGroupPendingCommitEntityQueryObject
    on
        QueryBuilder<
          ChatGroupPendingCommitEntity,
          ChatGroupPendingCommitEntity,
          QFilterCondition
        > {}

extension ChatGroupPendingCommitEntityQueryLinks
    on
        QueryBuilder<
          ChatGroupPendingCommitEntity,
          ChatGroupPendingCommitEntity,
          QFilterCondition
        > {}

extension ChatGroupPendingCommitEntityQuerySortBy
    on
        QueryBuilder<
          ChatGroupPendingCommitEntity,
          ChatGroupPendingCommitEntity,
          QSortBy
        > {
  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterSortBy
  >
  sortByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created_at', Sort.asc);
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterSortBy
  >
  sortByCreatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created_at', Sort.desc);
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterSortBy
  >
  sortByGroupId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'group_id', Sort.asc);
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterSortBy
  >
  sortByGroupIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'group_id', Sort.desc);
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterSortBy
  >
  sortByMessageBytesHex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message_bytes', Sort.asc);
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterSortBy
  >
  sortByMessageBytesHexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message_bytes', Sort.desc);
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterSortBy
  >
  sortByMessageEpoch() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message_epoch', Sort.asc);
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterSortBy
  >
  sortByMessageEpochDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message_epoch', Sort.desc);
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterSortBy
  >
  sortByMessageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message_id', Sort.asc);
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterSortBy
  >
  sortByMessageIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message_id', Sort.desc);
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterSortBy
  >
  sortByOwnerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'owner_id', Sort.asc);
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterSortBy
  >
  sortByOwnerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'owner_id', Sort.desc);
    });
  }
}

extension ChatGroupPendingCommitEntityQuerySortThenBy
    on
        QueryBuilder<
          ChatGroupPendingCommitEntity,
          ChatGroupPendingCommitEntity,
          QSortThenBy
        > {
  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterSortBy
  >
  thenByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created_at', Sort.asc);
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterSortBy
  >
  thenByCreatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'created_at', Sort.desc);
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterSortBy
  >
  thenByGroupId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'group_id', Sort.asc);
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterSortBy
  >
  thenByGroupIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'group_id', Sort.desc);
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterSortBy
  >
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterSortBy
  >
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterSortBy
  >
  thenByMessageBytesHex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message_bytes', Sort.asc);
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterSortBy
  >
  thenByMessageBytesHexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message_bytes', Sort.desc);
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterSortBy
  >
  thenByMessageEpoch() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message_epoch', Sort.asc);
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterSortBy
  >
  thenByMessageEpochDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message_epoch', Sort.desc);
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterSortBy
  >
  thenByMessageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message_id', Sort.asc);
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterSortBy
  >
  thenByMessageIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message_id', Sort.desc);
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterSortBy
  >
  thenByOwnerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'owner_id', Sort.asc);
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QAfterSortBy
  >
  thenByOwnerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'owner_id', Sort.desc);
    });
  }
}

extension ChatGroupPendingCommitEntityQueryWhereDistinct
    on
        QueryBuilder<
          ChatGroupPendingCommitEntity,
          ChatGroupPendingCommitEntity,
          QDistinct
        > {
  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QDistinct
  >
  distinctByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'created_at');
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QDistinct
  >
  distinctByGroupId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'group_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QDistinct
  >
  distinctByMessageBytesHex({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'message_bytes',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QDistinct
  >
  distinctByMessageEpoch() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'message_epoch');
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QDistinct
  >
  distinctByMessageId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'message_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<
    ChatGroupPendingCommitEntity,
    ChatGroupPendingCommitEntity,
    QDistinct
  >
  distinctByOwnerUserId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'owner_id', caseSensitive: caseSensitive);
    });
  }
}

extension ChatGroupPendingCommitEntityQueryProperty
    on
        QueryBuilder<
          ChatGroupPendingCommitEntity,
          ChatGroupPendingCommitEntity,
          QQueryProperty
        > {
  QueryBuilder<ChatGroupPendingCommitEntity, int, QQueryOperations>
  idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, int, QQueryOperations>
  createdAtMillisProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'created_at');
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, String, QQueryOperations>
  groupIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'group_id');
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, String, QQueryOperations>
  messageBytesHexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'message_bytes');
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, int, QQueryOperations>
  messageEpochProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'message_epoch');
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, String, QQueryOperations>
  messageIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'message_id');
    });
  }

  QueryBuilder<ChatGroupPendingCommitEntity, String, QQueryOperations>
  ownerUserIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'owner_id');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetChatBindingFenceEntityCollection on Isar {
  IsarCollection<ChatBindingFenceEntity> get chatBindingFenceEntitys =>
      this.collection();
}

const ChatBindingFenceEntitySchema = CollectionSchema(
  name: r'fence',
  id: -2181333600854589627,
  properties: {
    r'account_id': PropertySchema(
      id: 0,
      name: r'account_id',
      type: IsarType.string,
    ),
    r'bind_rev': PropertySchema(id: 1, name: r'bind_rev', type: IsarType.long),
    r'bind_scope': PropertySchema(
      id: 2,
      name: r'bind_scope',
      type: IsarType.string,
    ),
    r'fence_rev': PropertySchema(
      id: 3,
      name: r'fence_rev',
      type: IsarType.long,
    ),
    r'fence_state': PropertySchema(
      id: 4,
      name: r'fence_state',
      type: IsarType.string,
    ),
    r'owner_id': PropertySchema(
      id: 5,
      name: r'owner_id',
      type: IsarType.string,
    ),
  },

  estimateSize: _chatBindingFenceEntityEstimateSize,
  serialize: _chatBindingFenceEntitySerialize,
  deserialize: _chatBindingFenceEntityDeserialize,
  deserializeProp: _chatBindingFenceEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'owner_id': IndexSchema(
      id: -3543161581123061232,
      name: r'owner_id',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'owner_id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _chatBindingFenceEntityGetId,
  getLinks: _chatBindingFenceEntityGetLinks,
  attach: _chatBindingFenceEntityAttach,
  version: '3.3.2',
);

int _chatBindingFenceEntityEstimateSize(
  ChatBindingFenceEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.accountId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.bindingScope;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.fenceState.length * 3;
  bytesCount += 3 + object.ownerUserId.length * 3;
  return bytesCount;
}

void _chatBindingFenceEntitySerialize(
  ChatBindingFenceEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.accountId);
  writer.writeLong(offsets[1], object.bindingRevision);
  writer.writeString(offsets[2], object.bindingScope);
  writer.writeLong(offsets[3], object.generation);
  writer.writeString(offsets[4], object.fenceState);
  writer.writeString(offsets[5], object.ownerUserId);
}

ChatBindingFenceEntity _chatBindingFenceEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ChatBindingFenceEntity();
  object.accountId = reader.readStringOrNull(offsets[0]);
  object.bindingRevision = reader.readLongOrNull(offsets[1]);
  object.bindingScope = reader.readStringOrNull(offsets[2]);
  object.generation = reader.readLong(offsets[3]);
  object.fenceState = reader.readString(offsets[4]);
  object.id = id;
  object.ownerUserId = reader.readString(offsets[5]);
  return object;
}

P _chatBindingFenceEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readLongOrNull(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _chatBindingFenceEntityGetId(ChatBindingFenceEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _chatBindingFenceEntityGetLinks(
  ChatBindingFenceEntity object,
) {
  return [];
}

void _chatBindingFenceEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  ChatBindingFenceEntity object,
) {
  object.id = id;
}

extension ChatBindingFenceEntityByIndex
    on IsarCollection<ChatBindingFenceEntity> {
  Future<ChatBindingFenceEntity?> getByOwnerUserId(String ownerUserId) {
    return getByIndex(r'owner_id', [ownerUserId]);
  }

  ChatBindingFenceEntity? getByOwnerUserIdSync(String ownerUserId) {
    return getByIndexSync(r'owner_id', [ownerUserId]);
  }

  Future<bool> deleteByOwnerUserId(String ownerUserId) {
    return deleteByIndex(r'owner_id', [ownerUserId]);
  }

  bool deleteByOwnerUserIdSync(String ownerUserId) {
    return deleteByIndexSync(r'owner_id', [ownerUserId]);
  }

  Future<List<ChatBindingFenceEntity?>> getAllByOwnerUserId(
    List<String> ownerUserIdValues,
  ) {
    final values = ownerUserIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'owner_id', values);
  }

  List<ChatBindingFenceEntity?> getAllByOwnerUserIdSync(
    List<String> ownerUserIdValues,
  ) {
    final values = ownerUserIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'owner_id', values);
  }

  Future<int> deleteAllByOwnerUserId(List<String> ownerUserIdValues) {
    final values = ownerUserIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'owner_id', values);
  }

  int deleteAllByOwnerUserIdSync(List<String> ownerUserIdValues) {
    final values = ownerUserIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'owner_id', values);
  }

  Future<Id> putByOwnerUserId(ChatBindingFenceEntity object) {
    return putByIndex(r'owner_id', object);
  }

  Id putByOwnerUserIdSync(
    ChatBindingFenceEntity object, {
    bool saveLinks = true,
  }) {
    return putByIndexSync(r'owner_id', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByOwnerUserId(List<ChatBindingFenceEntity> objects) {
    return putAllByIndex(r'owner_id', objects);
  }

  List<Id> putAllByOwnerUserIdSync(
    List<ChatBindingFenceEntity> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'owner_id', objects, saveLinks: saveLinks);
  }
}

extension ChatBindingFenceEntityQueryWhereSort
    on QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QWhere> {
  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterWhere>
  anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ChatBindingFenceEntityQueryWhere
    on
        QueryBuilder<
          ChatBindingFenceEntity,
          ChatBindingFenceEntity,
          QWhereClause
        > {
  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterWhereClause
  >
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterWhereClause
  >
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

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterWhereClause
  >
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterWhereClause
  >
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterWhereClause
  >
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

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterWhereClause
  >
  ownerUserIdEqualTo(String ownerUserId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'owner_id', value: [ownerUserId]),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterWhereClause
  >
  ownerUserIdNotEqualTo(String ownerUserId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id',
                lower: [],
                upper: [ownerUserId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id',
                lower: [ownerUserId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id',
                lower: [ownerUserId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'owner_id',
                lower: [],
                upper: [ownerUserId],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension ChatBindingFenceEntityQueryFilter
    on
        QueryBuilder<
          ChatBindingFenceEntity,
          ChatBindingFenceEntity,
          QFilterCondition
        > {
  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  accountIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'account_id'),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  accountIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'account_id'),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  accountIdEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  accountIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  accountIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  accountIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'account_id',
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
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  accountIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  accountIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  accountIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'account_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  accountIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'account_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  accountIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'account_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  accountIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'account_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  bindingRevisionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'bind_rev'),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  bindingRevisionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'bind_rev'),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  bindingRevisionEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'bind_rev', value: value),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  bindingRevisionGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'bind_rev',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  bindingRevisionLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'bind_rev',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  bindingRevisionBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'bind_rev',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  bindingScopeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'bind_scope'),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  bindingScopeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'bind_scope'),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  bindingScopeEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'bind_scope',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  bindingScopeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'bind_scope',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  bindingScopeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'bind_scope',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  bindingScopeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'bind_scope',
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
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  bindingScopeStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'bind_scope',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  bindingScopeEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'bind_scope',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  bindingScopeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'bind_scope',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  bindingScopeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'bind_scope',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  bindingScopeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'bind_scope', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  bindingScopeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'bind_scope', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  generationEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'fence_rev', value: value),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  generationGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'fence_rev',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  generationLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'fence_rev',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  generationBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'fence_rev',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  fenceStateEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'fence_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  fenceStateGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'fence_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  fenceStateLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'fence_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  fenceStateBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'fence_state',
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
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  fenceStateStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'fence_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  fenceStateEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'fence_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  fenceStateContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'fence_state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  fenceStateMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'fence_state',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  fenceStateIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'fence_state', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  fenceStateIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'fence_state', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
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
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
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
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
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
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
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
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  ownerUserIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  ownerUserIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  ownerUserIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  ownerUserIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'owner_id',
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
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  ownerUserIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  ownerUserIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  ownerUserIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'owner_id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  ownerUserIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'owner_id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  ownerUserIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'owner_id', value: ''),
      );
    });
  }

  QueryBuilder<
    ChatBindingFenceEntity,
    ChatBindingFenceEntity,
    QAfterFilterCondition
  >
  ownerUserIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'owner_id', value: ''),
      );
    });
  }
}

extension ChatBindingFenceEntityQueryObject
    on
        QueryBuilder<
          ChatBindingFenceEntity,
          ChatBindingFenceEntity,
          QFilterCondition
        > {}

extension ChatBindingFenceEntityQueryLinks
    on
        QueryBuilder<
          ChatBindingFenceEntity,
          ChatBindingFenceEntity,
          QFilterCondition
        > {}

extension ChatBindingFenceEntityQuerySortBy
    on QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QSortBy> {
  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
  sortByAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
  sortByAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
  sortByBindingRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bind_rev', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
  sortByBindingRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bind_rev', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
  sortByBindingScope() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bind_scope', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
  sortByBindingScopeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bind_scope', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
  sortByGeneration() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fence_rev', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
  sortByGenerationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fence_rev', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
  sortByFenceState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fence_state', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
  sortByFenceStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fence_state', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
  sortByOwnerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'owner_id', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
  sortByOwnerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'owner_id', Sort.desc);
    });
  }
}

extension ChatBindingFenceEntityQuerySortThenBy
    on
        QueryBuilder<
          ChatBindingFenceEntity,
          ChatBindingFenceEntity,
          QSortThenBy
        > {
  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
  thenByAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
  thenByAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'account_id', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
  thenByBindingRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bind_rev', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
  thenByBindingRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bind_rev', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
  thenByBindingScope() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bind_scope', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
  thenByBindingScopeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bind_scope', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
  thenByGeneration() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fence_rev', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
  thenByGenerationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fence_rev', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
  thenByFenceState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fence_state', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
  thenByFenceStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fence_state', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
  thenByOwnerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'owner_id', Sort.asc);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QAfterSortBy>
  thenByOwnerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'owner_id', Sort.desc);
    });
  }
}

extension ChatBindingFenceEntityQueryWhereDistinct
    on QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QDistinct> {
  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QDistinct>
  distinctByAccountId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'account_id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QDistinct>
  distinctByBindingRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'bind_rev');
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QDistinct>
  distinctByBindingScope({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'bind_scope', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QDistinct>
  distinctByGeneration() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fence_rev');
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QDistinct>
  distinctByFenceState({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fence_state', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatBindingFenceEntity, ChatBindingFenceEntity, QDistinct>
  distinctByOwnerUserId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'owner_id', caseSensitive: caseSensitive);
    });
  }
}

extension ChatBindingFenceEntityQueryProperty
    on
        QueryBuilder<
          ChatBindingFenceEntity,
          ChatBindingFenceEntity,
          QQueryProperty
        > {
  QueryBuilder<ChatBindingFenceEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ChatBindingFenceEntity, String?, QQueryOperations>
  accountIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'account_id');
    });
  }

  QueryBuilder<ChatBindingFenceEntity, int?, QQueryOperations>
  bindingRevisionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'bind_rev');
    });
  }

  QueryBuilder<ChatBindingFenceEntity, String?, QQueryOperations>
  bindingScopeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'bind_scope');
    });
  }

  QueryBuilder<ChatBindingFenceEntity, int, QQueryOperations>
  generationProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fence_rev');
    });
  }

  QueryBuilder<ChatBindingFenceEntity, String, QQueryOperations>
  fenceStateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fence_state');
    });
  }

  QueryBuilder<ChatBindingFenceEntity, String, QQueryOperations>
  ownerUserIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'owner_id');
    });
  }
}
