part of 'generated.dart';

class UpdateMessageVariablesBuilder {
  String id;
  final Optional<String> _content = Optional.optional(nativeFromJson, nativeToJson);

  final FirebaseDataConnect _dataConnect;  UpdateMessageVariablesBuilder content(String? t) {
   _content.value = t;
   return this;
  }

  UpdateMessageVariablesBuilder(this._dataConnect, {required  this.id,});
  Deserializer<UpdateMessageData> dataDeserializer = (dynamic json)  => UpdateMessageData.fromJson(jsonDecode(json));
  Serializer<UpdateMessageVariables> varsSerializer = (UpdateMessageVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<UpdateMessageData, UpdateMessageVariables>> execute() {
    return ref().execute();
  }

  MutationRef<UpdateMessageData, UpdateMessageVariables> ref() {
    UpdateMessageVariables vars= UpdateMessageVariables(id: id,content: _content,);
    return _dataConnect.mutation("UpdateMessage", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class UpdateMessageMessageUpdate {
  final String id;
  UpdateMessageMessageUpdate.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateMessageMessageUpdate otherTyped = other as UpdateMessageMessageUpdate;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  const UpdateMessageMessageUpdate({
    required this.id,
  });
}

@immutable
class UpdateMessageData {
  final UpdateMessageMessageUpdate? message_update;
  UpdateMessageData.fromJson(dynamic json):
  
  message_update = json['message_update'] == null ? null : UpdateMessageMessageUpdate.fromJson(json['message_update']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateMessageData otherTyped = other as UpdateMessageData;
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

  const UpdateMessageData({
    this.message_update,
  });
}

@immutable
class UpdateMessageVariables {
  final String id;
  late final Optional<String>content;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  UpdateMessageVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']) {
  
  
  
    content = Optional.optional(nativeFromJson, nativeToJson);
    content.value = json['content'] == null ? null : nativeFromJson<String>(json['content']);
  
  }
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateMessageVariables otherTyped = other as UpdateMessageVariables;
    return id == otherTyped.id && 
    content == otherTyped.content;
    
  }
  @override
  int get hashCode => Object.hashAll([id.hashCode, content.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    if(content.state == OptionalState.set) {
      json['content'] = content.toJson();
    }
    return json;
  }

  const UpdateMessageVariables({
    required this.id,
    required this.content,
  });
}

