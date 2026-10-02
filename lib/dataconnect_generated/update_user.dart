part of 'generated.dart';

class UpdateUserVariablesBuilder {
  final Optional<String> _username = Optional.optional(nativeFromJson, nativeToJson);

  final FirebaseDataConnect _dataConnect;
  UpdateUserVariablesBuilder username(String? t) {
   _username.value = t;
   return this;
  }

  UpdateUserVariablesBuilder(this._dataConnect, );
  Deserializer<UpdateUserData> dataDeserializer = (dynamic json)  => UpdateUserData.fromJson(jsonDecode(json));
  Serializer<UpdateUserVariables> varsSerializer = (UpdateUserVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<UpdateUserData, UpdateUserVariables>> execute() {
    return ref().execute();
  }

  MutationRef<UpdateUserData, UpdateUserVariables> ref() {
    UpdateUserVariables vars= UpdateUserVariables(username: _username,);
    return _dataConnect.mutation("UpdateUser", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class UpdateUserUserUpdate {
  final String id;
  UpdateUserUserUpdate.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateUserUserUpdate otherTyped = other as UpdateUserUserUpdate;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  const UpdateUserUserUpdate({
    required this.id,
  });
}

@immutable
class UpdateUserData {
  final UpdateUserUserUpdate? user_update;
  UpdateUserData.fromJson(dynamic json):
  
  user_update = json['user_update'] == null ? null : UpdateUserUserUpdate.fromJson(json['user_update']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateUserData otherTyped = other as UpdateUserData;
    return user_update == otherTyped.user_update;
    
  }
  @override
  int get hashCode => user_update.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (user_update != null) {
      json['user_update'] = user_update!.toJson();
    }
    return json;
  }

  const UpdateUserData({
    this.user_update,
  });
}

@immutable
class UpdateUserVariables {
  late final Optional<String>username;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  UpdateUserVariables.fromJson(Map<String, dynamic> json) {
  
  
    username = Optional.optional(nativeFromJson, nativeToJson);
    username.value = json['username'] == null ? null : nativeFromJson<String>(json['username']);
  
  }
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateUserVariables otherTyped = other as UpdateUserVariables;
    return username == otherTyped.username;
    
  }
  @override
  int get hashCode => username.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if(username.state == OptionalState.set) {
      json['username'] = username.toJson();
    }
    return json;
  }

  const UpdateUserVariables({
    required this.username,
  });
}

