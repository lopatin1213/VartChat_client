part of 'generated.dart';

class GetChatVariablesBuilder {
  String id;

  final FirebaseDataConnect _dataConnect;
  GetChatVariablesBuilder(this._dataConnect, {required  this.id,});
  Deserializer<GetChatData> dataDeserializer = (dynamic json)  => GetChatData.fromJson(jsonDecode(json));
  Serializer<GetChatVariables> varsSerializer = (GetChatVariables vars) => jsonEncode(vars.toJson());
  Future<QueryResult<GetChatData, GetChatVariables>> execute({QueryFetchPolicy fetchPolicy = QueryFetchPolicy.preferCache}) {
    return ref().execute(fetchPolicy: fetchPolicy);
  }

  QueryRef<GetChatData, GetChatVariables> ref() {
    GetChatVariables vars= GetChatVariables(id: id,);
    return _dataConnect.query("GetChat", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class GetChatChat {
  final String? name;
  final bool isGroup;
  GetChatChat.fromJson(dynamic json):
  
  name = json['name'] == null ? null : nativeFromJson<String>(json['name']),
  isGroup = nativeFromJson<bool>(json['isGroup']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetChatChat otherTyped = other as GetChatChat;
    return name == otherTyped.name && 
    isGroup == otherTyped.isGroup;
    
  }
  @override
  int get hashCode => Object.hashAll([name.hashCode, isGroup.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (name != null) {
      json['name'] = nativeToJson<String?>(name);
    }
    json['isGroup'] = nativeToJson<bool>(isGroup);
    return json;
  }

  const GetChatChat({
    this.name,
    required this.isGroup,
  });
}

@immutable
class GetChatData {
  final GetChatChat? chat;
  GetChatData.fromJson(dynamic json):
  
  chat = json['chat'] == null ? null : GetChatChat.fromJson(json['chat']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetChatData otherTyped = other as GetChatData;
    return chat == otherTyped.chat;
    
  }
  @override
  int get hashCode => chat.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (chat != null) {
      json['chat'] = chat!.toJson();
    }
    return json;
  }

  const GetChatData({
    this.chat,
  });
}

@immutable
class GetChatVariables {
  final String id;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  GetChatVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetChatVariables otherTyped = other as GetChatVariables;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  const GetChatVariables({
    required this.id,
  });
}

