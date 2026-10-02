part of 'generated.dart';

class DeleteChatParticipantVariablesBuilder {
  String id;

  final FirebaseDataConnect _dataConnect;
  DeleteChatParticipantVariablesBuilder(this._dataConnect, {required  this.id,});
  Deserializer<DeleteChatParticipantData> dataDeserializer = (dynamic json)  => DeleteChatParticipantData.fromJson(jsonDecode(json));
  Serializer<DeleteChatParticipantVariables> varsSerializer = (DeleteChatParticipantVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<DeleteChatParticipantData, DeleteChatParticipantVariables>> execute() {
    return ref().execute();
  }

  MutationRef<DeleteChatParticipantData, DeleteChatParticipantVariables> ref() {
    DeleteChatParticipantVariables vars= DeleteChatParticipantVariables(id: id,);
    return _dataConnect.mutation("DeleteChatParticipant", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class DeleteChatParticipantChatParticipantDelete {
  final String id;
  DeleteChatParticipantChatParticipantDelete.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteChatParticipantChatParticipantDelete otherTyped = other as DeleteChatParticipantChatParticipantDelete;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  const DeleteChatParticipantChatParticipantDelete({
    required this.id,
  });
}

@immutable
class DeleteChatParticipantData {
  final DeleteChatParticipantChatParticipantDelete? chatParticipant_delete;
  DeleteChatParticipantData.fromJson(dynamic json):
  
  chatParticipant_delete = json['chatParticipant_delete'] == null ? null : DeleteChatParticipantChatParticipantDelete.fromJson(json['chatParticipant_delete']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteChatParticipantData otherTyped = other as DeleteChatParticipantData;
    return chatParticipant_delete == otherTyped.chatParticipant_delete;
    
  }
  @override
  int get hashCode => chatParticipant_delete.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (chatParticipant_delete != null) {
      json['chatParticipant_delete'] = chatParticipant_delete!.toJson();
    }
    return json;
  }

  const DeleteChatParticipantData({
    this.chatParticipant_delete,
  });
}

@immutable
class DeleteChatParticipantVariables {
  final String id;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  DeleteChatParticipantVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteChatParticipantVariables otherTyped = other as DeleteChatParticipantVariables;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  const DeleteChatParticipantVariables({
    required this.id,
  });
}

