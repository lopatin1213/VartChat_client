part of 'generated.dart';

class GetMessageVariablesBuilder {
  String id;

  final FirebaseDataConnect _dataConnect;
  GetMessageVariablesBuilder(this._dataConnect, {required  this.id,});
  Deserializer<GetMessageData> dataDeserializer = (dynamic json)  => GetMessageData.fromJson(jsonDecode(json));
  Serializer<GetMessageVariables> varsSerializer = (GetMessageVariables vars) => jsonEncode(vars.toJson());
  Future<QueryResult<GetMessageData, GetMessageVariables>> execute({QueryFetchPolicy fetchPolicy = QueryFetchPolicy.preferCache}) {
    return ref().execute(fetchPolicy: fetchPolicy);
  }

  QueryRef<GetMessageData, GetMessageVariables> ref() {
    GetMessageVariables vars= GetMessageVariables(id: id,);
    return _dataConnect.query("GetMessage", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class GetMessageMessage {
  final String content;
  final GetMessageMessageSender sender;
  GetMessageMessage.fromJson(dynamic json):
  
  content = nativeFromJson<String>(json['content']),
  sender = GetMessageMessageSender.fromJson(json['sender']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetMessageMessage otherTyped = other as GetMessageMessage;
    return content == otherTyped.content && 
    sender == otherTyped.sender;
    
  }
  @override
  int get hashCode => Object.hashAll([content.hashCode, sender.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['content'] = nativeToJson<String>(content);
    json['sender'] = sender.toJson();
    return json;
  }

  const GetMessageMessage({
    required this.content,
    required this.sender,
  });
}

@immutable
class GetMessageMessageSender {
  final String username;
  GetMessageMessageSender.fromJson(dynamic json):
  
  username = nativeFromJson<String>(json['username']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetMessageMessageSender otherTyped = other as GetMessageMessageSender;
    return username == otherTyped.username;
    
  }
  @override
  int get hashCode => username.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['username'] = nativeToJson<String>(username);
    return json;
  }

  const GetMessageMessageSender({
    required this.username,
  });
}

@immutable
class GetMessageData {
  final GetMessageMessage? message;
  GetMessageData.fromJson(dynamic json):
  
  message = json['message'] == null ? null : GetMessageMessage.fromJson(json['message']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetMessageData otherTyped = other as GetMessageData;
    return message == otherTyped.message;
    
  }
  @override
  int get hashCode => message.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (message != null) {
      json['message'] = message!.toJson();
    }
    return json;
  }

  const GetMessageData({
    this.message,
  });
}

@immutable
class GetMessageVariables {
  final String id;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  GetMessageVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetMessageVariables otherTyped = other as GetMessageVariables;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  const GetMessageVariables({
    required this.id,
  });
}

