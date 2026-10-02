part of 'generated.dart';

class CreateChatParticipantVariablesBuilder {
  String chatId;

  final FirebaseDataConnect _dataConnect;
  CreateChatParticipantVariablesBuilder(this._dataConnect, {required  this.chatId,});
  Deserializer<CreateChatParticipantData> dataDeserializer = (dynamic json)  => CreateChatParticipantData.fromJson(jsonDecode(json));
  Serializer<CreateChatParticipantVariables> varsSerializer = (CreateChatParticipantVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<CreateChatParticipantData, CreateChatParticipantVariables>> execute() {
    return ref().execute();
  }

  MutationRef<CreateChatParticipantData, CreateChatParticipantVariables> ref() {
    CreateChatParticipantVariables vars= CreateChatParticipantVariables(chatId: chatId,);
    return _dataConnect.mutation("CreateChatParticipant", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class CreateChatParticipantChatParticipantInsert {
  final String id;
  CreateChatParticipantChatParticipantInsert.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateChatParticipantChatParticipantInsert otherTyped = other as CreateChatParticipantChatParticipantInsert;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  const CreateChatParticipantChatParticipantInsert({
    required this.id,
  });
}

@immutable
class CreateChatParticipantData {
  final CreateChatParticipantChatParticipantInsert chatParticipant_insert;
  CreateChatParticipantData.fromJson(dynamic json):
  
  chatParticipant_insert = CreateChatParticipantChatParticipantInsert.fromJson(json['chatParticipant_insert']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateChatParticipantData otherTyped = other as CreateChatParticipantData;
    return chatParticipant_insert == otherTyped.chatParticipant_insert;
    
  }
  @override
  int get hashCode => chatParticipant_insert.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['chatParticipant_insert'] = chatParticipant_insert.toJson();
    return json;
  }

  const CreateChatParticipantData({
    required this.chatParticipant_insert,
  });
}

@immutable
class CreateChatParticipantVariables {
  final String chatId;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  CreateChatParticipantVariables.fromJson(Map<String, dynamic> json):
  
  chatId = nativeFromJson<String>(json['chatId']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateChatParticipantVariables otherTyped = other as CreateChatParticipantVariables;
    return chatId == otherTyped.chatId;
    
  }
  @override
  int get hashCode => chatId.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['chatId'] = nativeToJson<String>(chatId);
    return json;
  }

  const CreateChatParticipantVariables({
    required this.chatId,
  });
}

