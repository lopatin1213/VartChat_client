part of 'generated.dart';

class ListChatParticipantsVariablesBuilder {
  String chatId;

  final FirebaseDataConnect _dataConnect;
  ListChatParticipantsVariablesBuilder(this._dataConnect, {required  this.chatId,});
  Deserializer<ListChatParticipantsData> dataDeserializer = (dynamic json)  => ListChatParticipantsData.fromJson(jsonDecode(json));
  Serializer<ListChatParticipantsVariables> varsSerializer = (ListChatParticipantsVariables vars) => jsonEncode(vars.toJson());
  Future<QueryResult<ListChatParticipantsData, ListChatParticipantsVariables>> execute({QueryFetchPolicy fetchPolicy = QueryFetchPolicy.preferCache}) {
    return ref().execute(fetchPolicy: fetchPolicy);
  }

  QueryRef<ListChatParticipantsData, ListChatParticipantsVariables> ref() {
    ListChatParticipantsVariables vars= ListChatParticipantsVariables(chatId: chatId,);
    return _dataConnect.query("ListChatParticipants", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class ListChatParticipantsChatParticipants {
  final ListChatParticipantsChatParticipantsUser user;
  ListChatParticipantsChatParticipants.fromJson(dynamic json):
  
  user = ListChatParticipantsChatParticipantsUser.fromJson(json['user']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListChatParticipantsChatParticipants otherTyped = other as ListChatParticipantsChatParticipants;
    return user == otherTyped.user;
    
  }
  @override
  int get hashCode => user.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['user'] = user.toJson();
    return json;
  }

  const ListChatParticipantsChatParticipants({
    required this.user,
  });
}

@immutable
class ListChatParticipantsChatParticipantsUser {
  final String username;
  ListChatParticipantsChatParticipantsUser.fromJson(dynamic json):
  
  username = nativeFromJson<String>(json['username']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListChatParticipantsChatParticipantsUser otherTyped = other as ListChatParticipantsChatParticipantsUser;
    return username == otherTyped.username;
    
  }
  @override
  int get hashCode => username.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['username'] = nativeToJson<String>(username);
    return json;
  }

  const ListChatParticipantsChatParticipantsUser({
    required this.username,
  });
}

@immutable
class ListChatParticipantsData {
  final List<ListChatParticipantsChatParticipants> chatParticipants;
  ListChatParticipantsData.fromJson(dynamic json):
  
  chatParticipants = (json['chatParticipants'] as List<dynamic>)
        .map((e) => ListChatParticipantsChatParticipants.fromJson(e))
        .toList();
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListChatParticipantsData otherTyped = other as ListChatParticipantsData;
    return chatParticipants == otherTyped.chatParticipants;
    
  }
  @override
  int get hashCode => chatParticipants.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['chatParticipants'] = chatParticipants.map((e) => e.toJson()).toList();
    return json;
  }

  const ListChatParticipantsData({
    required this.chatParticipants,
  });
}

@immutable
class ListChatParticipantsVariables {
  final String chatId;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  ListChatParticipantsVariables.fromJson(Map<String, dynamic> json):
  
  chatId = nativeFromJson<String>(json['chatId']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListChatParticipantsVariables otherTyped = other as ListChatParticipantsVariables;
    return chatId == otherTyped.chatId;
    
  }
  @override
  int get hashCode => chatId.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['chatId'] = nativeToJson<String>(chatId);
    return json;
  }

  const ListChatParticipantsVariables({
    required this.chatId,
  });
}

