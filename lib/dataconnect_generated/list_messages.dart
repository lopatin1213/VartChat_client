part of 'generated.dart';

class ListMessagesVariablesBuilder {
  String chatId;

  final FirebaseDataConnect _dataConnect;
  ListMessagesVariablesBuilder(this._dataConnect, {required  this.chatId,});
  Deserializer<ListMessagesData> dataDeserializer = (dynamic json)  => ListMessagesData.fromJson(jsonDecode(json));
  Serializer<ListMessagesVariables> varsSerializer = (ListMessagesVariables vars) => jsonEncode(vars.toJson());
  Future<QueryResult<ListMessagesData, ListMessagesVariables>> execute({QueryFetchPolicy fetchPolicy = QueryFetchPolicy.preferCache}) {
    return ref().execute(fetchPolicy: fetchPolicy);
  }

  QueryRef<ListMessagesData, ListMessagesVariables> ref() {
    ListMessagesVariables vars= ListMessagesVariables(chatId: chatId,);
    return _dataConnect.query("ListMessages", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class ListMessagesMessages {
  final String content;
  final Timestamp timestamp;
  ListMessagesMessages.fromJson(dynamic json):
  
  content = nativeFromJson<String>(json['content']),
  timestamp = Timestamp.fromJson(json['timestamp']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListMessagesMessages otherTyped = other as ListMessagesMessages;
    return content == otherTyped.content && 
    timestamp == otherTyped.timestamp;
    
  }
  @override
  int get hashCode => Object.hashAll([content.hashCode, timestamp.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['content'] = nativeToJson<String>(content);
    json['timestamp'] = timestamp.toJson();
    return json;
  }

  const ListMessagesMessages({
    required this.content,
    required this.timestamp,
  });
}

@immutable
class ListMessagesData {
  final List<ListMessagesMessages> messages;
  ListMessagesData.fromJson(dynamic json):
  
  messages = (json['messages'] as List<dynamic>)
        .map((e) => ListMessagesMessages.fromJson(e))
        .toList();
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListMessagesData otherTyped = other as ListMessagesData;
    return messages == otherTyped.messages;
    
  }
  @override
  int get hashCode => messages.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['messages'] = messages.map((e) => e.toJson()).toList();
    return json;
  }

  const ListMessagesData({
    required this.messages,
  });
}

@immutable
class ListMessagesVariables {
  final String chatId;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  ListMessagesVariables.fromJson(Map<String, dynamic> json):
  
  chatId = nativeFromJson<String>(json['chatId']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListMessagesVariables otherTyped = other as ListMessagesVariables;
    return chatId == otherTyped.chatId;
    
  }
  @override
  int get hashCode => chatId.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['chatId'] = nativeToJson<String>(chatId);
    return json;
  }

  const ListMessagesVariables({
    required this.chatId,
  });
}

