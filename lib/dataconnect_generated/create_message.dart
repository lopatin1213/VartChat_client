part of 'generated.dart';

class CreateMessageVariablesBuilder {
  String chatId;
  String content;

  final FirebaseDataConnect _dataConnect;
  CreateMessageVariablesBuilder(this._dataConnect, {required  this.chatId,required  this.content,});
  Deserializer<CreateMessageData> dataDeserializer = (dynamic json)  => CreateMessageData.fromJson(jsonDecode(json));
  Serializer<CreateMessageVariables> varsSerializer = (CreateMessageVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<CreateMessageData, CreateMessageVariables>> execute() {
    return ref().execute();
  }

  MutationRef<CreateMessageData, CreateMessageVariables> ref() {
    CreateMessageVariables vars= CreateMessageVariables(chatId: chatId,content: content,);
    return _dataConnect.mutation("CreateMessage", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class CreateMessageMessageInsert {
  final String id;
  CreateMessageMessageInsert.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateMessageMessageInsert otherTyped = other as CreateMessageMessageInsert;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  const CreateMessageMessageInsert({
    required this.id,
  });
}

@immutable
class CreateMessageData {
  final CreateMessageMessageInsert message_insert;
  CreateMessageData.fromJson(dynamic json):
  
  message_insert = CreateMessageMessageInsert.fromJson(json['message_insert']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateMessageData otherTyped = other as CreateMessageData;
    return message_insert == otherTyped.message_insert;
    
  }
  @override
  int get hashCode => message_insert.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['message_insert'] = message_insert.toJson();
    return json;
  }

  const CreateMessageData({
    required this.message_insert,
  });
}

@immutable
class CreateMessageVariables {
  final String chatId;
  final String content;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  CreateMessageVariables.fromJson(Map<String, dynamic> json):
  
  chatId = nativeFromJson<String>(json['chatId']),
  content = nativeFromJson<String>(json['content']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateMessageVariables otherTyped = other as CreateMessageVariables;
    return chatId == otherTyped.chatId && 
    content == otherTyped.content;
    
  }
  @override
  int get hashCode => Object.hashAll([chatId.hashCode, content.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['chatId'] = nativeToJson<String>(chatId);
    json['content'] = nativeToJson<String>(content);
    return json;
  }

  const CreateMessageVariables({
    required this.chatId,
    required this.content,
  });
}

