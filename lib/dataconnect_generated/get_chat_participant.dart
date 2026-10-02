part of 'generated.dart';

class GetChatParticipantVariablesBuilder {
  String id;

  final FirebaseDataConnect _dataConnect;
  GetChatParticipantVariablesBuilder(this._dataConnect, {required  this.id,});
  Deserializer<GetChatParticipantData> dataDeserializer = (dynamic json)  => GetChatParticipantData.fromJson(jsonDecode(json));
  Serializer<GetChatParticipantVariables> varsSerializer = (GetChatParticipantVariables vars) => jsonEncode(vars.toJson());
  Future<QueryResult<GetChatParticipantData, GetChatParticipantVariables>> execute({QueryFetchPolicy fetchPolicy = QueryFetchPolicy.preferCache}) {
    return ref().execute(fetchPolicy: fetchPolicy);
  }

  QueryRef<GetChatParticipantData, GetChatParticipantVariables> ref() {
    GetChatParticipantVariables vars= GetChatParticipantVariables(id: id,);
    return _dataConnect.query("GetChatParticipant", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class GetChatParticipantChatParticipant {
  final GetChatParticipantChatParticipantUser user;
  final Timestamp joinedAt;
  GetChatParticipantChatParticipant.fromJson(dynamic json):
  
  user = GetChatParticipantChatParticipantUser.fromJson(json['user']),
  joinedAt = Timestamp.fromJson(json['joinedAt']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetChatParticipantChatParticipant otherTyped = other as GetChatParticipantChatParticipant;
    return user == otherTyped.user && 
    joinedAt == otherTyped.joinedAt;
    
  }
  @override
  int get hashCode => Object.hashAll([user.hashCode, joinedAt.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['user'] = user.toJson();
    json['joinedAt'] = joinedAt.toJson();
    return json;
  }

  const GetChatParticipantChatParticipant({
    required this.user,
    required this.joinedAt,
  });
}

@immutable
class GetChatParticipantChatParticipantUser {
  final String username;
  GetChatParticipantChatParticipantUser.fromJson(dynamic json):
  
  username = nativeFromJson<String>(json['username']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetChatParticipantChatParticipantUser otherTyped = other as GetChatParticipantChatParticipantUser;
    return username == otherTyped.username;
    
  }
  @override
  int get hashCode => username.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['username'] = nativeToJson<String>(username);
    return json;
  }

  const GetChatParticipantChatParticipantUser({
    required this.username,
  });
}

@immutable
class GetChatParticipantData {
  final GetChatParticipantChatParticipant? chatParticipant;
  GetChatParticipantData.fromJson(dynamic json):
  
  chatParticipant = json['chatParticipant'] == null ? null : GetChatParticipantChatParticipant.fromJson(json['chatParticipant']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetChatParticipantData otherTyped = other as GetChatParticipantData;
    return chatParticipant == otherTyped.chatParticipant;
    
  }
  @override
  int get hashCode => chatParticipant.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (chatParticipant != null) {
      json['chatParticipant'] = chatParticipant!.toJson();
    }
    return json;
  }

  const GetChatParticipantData({
    this.chatParticipant,
  });
}

@immutable
class GetChatParticipantVariables {
  final String id;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  GetChatParticipantVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetChatParticipantVariables otherTyped = other as GetChatParticipantVariables;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  const GetChatParticipantVariables({
    required this.id,
  });
}

