part of 'generated.dart';

class DeleteMessageVariablesBuilder {
  String id;

  final FirebaseDataConnect _dataConnect;
  DeleteMessageVariablesBuilder(this._dataConnect, {required  this.id,});
  Deserializer<DeleteMessageData> dataDeserializer = (dynamic json)  => DeleteMessageData.fromJson(jsonDecode(json));
  Serializer<DeleteMessageVariables> varsSerializer = (DeleteMessageVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<DeleteMessageData, DeleteMessageVariables>> execute() {
    return ref().execute();
  }

  MutationRef<DeleteMessageData, DeleteMessageVariables> ref() {
    DeleteMessageVariables vars= DeleteMessageVariables(id: id,);
    return _dataConnect.mutation("DeleteMessage", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class DeleteMessageMessageUpdate {
  final String id;
  DeleteMessageMessageUpdate.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteMessageMessageUpdate otherTyped = other as DeleteMessageMessageUpdate;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  const DeleteMessageMessageUpdate({
    required this.id,
  });
}

@immutable
class DeleteMessageData {
  final DeleteMessageMessageUpdate? message_update;
  DeleteMessageData.fromJson(dynamic json):
  
  message_update = json['message_update'] == null ? null : DeleteMessageMessageUpdate.fromJson(json['message_update']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteMessageData otherTyped = other as DeleteMessageData;
    return message_update == otherTyped.message_update;
    
  }
  @override
  int get hashCode => message_update.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (message_update != null) {
      json['message_update'] = message_update!.toJson();
    }
    return json;
  }

  const DeleteMessageData({
    this.message_update,
  });
}

@immutable
class DeleteMessageVariables {
  final String id;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  DeleteMessageVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteMessageVariables otherTyped = other as DeleteMessageVariables;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  const DeleteMessageVariables({
    required this.id,
  });
}

