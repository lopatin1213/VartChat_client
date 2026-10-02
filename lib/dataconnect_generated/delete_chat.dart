part of 'generated.dart';

class DeleteChatVariablesBuilder {
  String id;

  final FirebaseDataConnect _dataConnect;
  DeleteChatVariablesBuilder(this._dataConnect, {required  this.id,});
  Deserializer<DeleteChatData> dataDeserializer = (dynamic json)  => DeleteChatData.fromJson(jsonDecode(json));
  Serializer<DeleteChatVariables> varsSerializer = (DeleteChatVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<DeleteChatData, DeleteChatVariables>> execute() {
    return ref().execute();
  }

  MutationRef<DeleteChatData, DeleteChatVariables> ref() {
    DeleteChatVariables vars= DeleteChatVariables(id: id,);
    return _dataConnect.mutation("DeleteChat", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class DeleteChatChatDelete {
  final String id;
  DeleteChatChatDelete.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteChatChatDelete otherTyped = other as DeleteChatChatDelete;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  const DeleteChatChatDelete({
    required this.id,
  });
}

@immutable
class DeleteChatData {
  final DeleteChatChatDelete? chat_delete;
  DeleteChatData.fromJson(dynamic json):
  
  chat_delete = json['chat_delete'] == null ? null : DeleteChatChatDelete.fromJson(json['chat_delete']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteChatData otherTyped = other as DeleteChatData;
    return chat_delete == otherTyped.chat_delete;
    
  }
  @override
  int get hashCode => chat_delete.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (chat_delete != null) {
      json['chat_delete'] = chat_delete!.toJson();
    }
    return json;
  }

  const DeleteChatData({
    this.chat_delete,
  });
}

@immutable
class DeleteChatVariables {
  final String id;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  DeleteChatVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteChatVariables otherTyped = other as DeleteChatVariables;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  const DeleteChatVariables({
    required this.id,
  });
}

