part of 'generated.dart';

class UpdateChatVariablesBuilder {
  String id;
  final Optional<String> _name = Optional.optional(nativeFromJson, nativeToJson);

  final FirebaseDataConnect _dataConnect;  UpdateChatVariablesBuilder name(String? t) {
   _name.value = t;
   return this;
  }

  UpdateChatVariablesBuilder(this._dataConnect, {required  this.id,});
  Deserializer<UpdateChatData> dataDeserializer = (dynamic json)  => UpdateChatData.fromJson(jsonDecode(json));
  Serializer<UpdateChatVariables> varsSerializer = (UpdateChatVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<UpdateChatData, UpdateChatVariables>> execute() {
    return ref().execute();
  }

  MutationRef<UpdateChatData, UpdateChatVariables> ref() {
    UpdateChatVariables vars= UpdateChatVariables(id: id,name: _name,);
    return _dataConnect.mutation("UpdateChat", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class UpdateChatChatUpdate {
  final String id;
  UpdateChatChatUpdate.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateChatChatUpdate otherTyped = other as UpdateChatChatUpdate;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  const UpdateChatChatUpdate({
    required this.id,
  });
}

@immutable
class UpdateChatData {
  final UpdateChatChatUpdate? chat_update;
  UpdateChatData.fromJson(dynamic json):
  
  chat_update = json['chat_update'] == null ? null : UpdateChatChatUpdate.fromJson(json['chat_update']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateChatData otherTyped = other as UpdateChatData;
    return chat_update == otherTyped.chat_update;
    
  }
  @override
  int get hashCode => chat_update.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (chat_update != null) {
      json['chat_update'] = chat_update!.toJson();
    }
    return json;
  }

  const UpdateChatData({
    this.chat_update,
  });
}

@immutable
class UpdateChatVariables {
  final String id;
  late final Optional<String>name;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  UpdateChatVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']) {
  
  
  
    name = Optional.optional(nativeFromJson, nativeToJson);
    name.value = json['name'] == null ? null : nativeFromJson<String>(json['name']);
  
  }
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateChatVariables otherTyped = other as UpdateChatVariables;
    return id == otherTyped.id && 
    name == otherTyped.name;
    
  }
  @override
  int get hashCode => Object.hashAll([id.hashCode, name.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    if(name.state == OptionalState.set) {
      json['name'] = name.toJson();
    }
    return json;
  }

  const UpdateChatVariables({
    required this.id,
    required this.name,
  });
}

