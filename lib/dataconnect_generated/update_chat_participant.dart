part of 'generated.dart';

class UpdateChatParticipantVariablesBuilder {
  String id;
  Timestamp joinedAt;

  final FirebaseDataConnect _dataConnect;
  UpdateChatParticipantVariablesBuilder(this._dataConnect, {required  this.id,required  this.joinedAt,});
  Deserializer<UpdateChatParticipantData> dataDeserializer = (dynamic json)  => UpdateChatParticipantData.fromJson(jsonDecode(json));
  Serializer<UpdateChatParticipantVariables> varsSerializer = (UpdateChatParticipantVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<UpdateChatParticipantData, UpdateChatParticipantVariables>> execute() {
    return ref().execute();
  }

  MutationRef<UpdateChatParticipantData, UpdateChatParticipantVariables> ref() {
    UpdateChatParticipantVariables vars= UpdateChatParticipantVariables(id: id,joinedAt: joinedAt,);
    return _dataConnect.mutation("UpdateChatParticipant", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class UpdateChatParticipantChatParticipantUpdate {
  final String id;
  UpdateChatParticipantChatParticipantUpdate.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateChatParticipantChatParticipantUpdate otherTyped = other as UpdateChatParticipantChatParticipantUpdate;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  const UpdateChatParticipantChatParticipantUpdate({
    required this.id,
  });
}

@immutable
class UpdateChatParticipantData {
  final UpdateChatParticipantChatParticipantUpdate? chatParticipant_update;
  UpdateChatParticipantData.fromJson(dynamic json):
  
  chatParticipant_update = json['chatParticipant_update'] == null ? null : UpdateChatParticipantChatParticipantUpdate.fromJson(json['chatParticipant_update']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateChatParticipantData otherTyped = other as UpdateChatParticipantData;
    return chatParticipant_update == otherTyped.chatParticipant_update;
    
  }
  @override
  int get hashCode => chatParticipant_update.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (chatParticipant_update != null) {
      json['chatParticipant_update'] = chatParticipant_update!.toJson();
    }
    return json;
  }

  const UpdateChatParticipantData({
    this.chatParticipant_update,
  });
}

@immutable
class UpdateChatParticipantVariables {
  final String id;
  final Timestamp joinedAt;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  UpdateChatParticipantVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']),
  joinedAt = Timestamp.fromJson(json['joinedAt']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateChatParticipantVariables otherTyped = other as UpdateChatParticipantVariables;
    return id == otherTyped.id && 
    joinedAt == otherTyped.joinedAt;
    
  }
  @override
  int get hashCode => Object.hashAll([id.hashCode, joinedAt.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    json['joinedAt'] = joinedAt.toJson();
    return json;
  }

  const UpdateChatParticipantVariables({
    required this.id,
    required this.joinedAt,
  });
}

