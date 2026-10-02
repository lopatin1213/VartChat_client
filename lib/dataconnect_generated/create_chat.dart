part of 'generated.dart';

class CreateChatVariablesBuilder {
  bool isGroup;
  final Optional<String> _name = Optional.optional(nativeFromJson, nativeToJson);

  final FirebaseDataConnect _dataConnect;  CreateChatVariablesBuilder name(String? t) {
   _name.value = t;
   return this;
  }

  CreateChatVariablesBuilder(this._dataConnect, {required  this.isGroup,});
  Deserializer<CreateChatData> dataDeserializer = (dynamic json)  => CreateChatData.fromJson(jsonDecode(json));
  Serializer<CreateChatVariables> varsSerializer = (CreateChatVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<CreateChatData, CreateChatVariables>> execute() {
    return ref().execute();
  }

  MutationRef<CreateChatData, CreateChatVariables> ref() {
    CreateChatVariables vars= CreateChatVariables(isGroup: isGroup,name: _name,);
    return _dataConnect.mutation("CreateChat", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class CreateChatChatInsert {
  final String id;
  CreateChatChatInsert.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateChatChatInsert otherTyped = other as CreateChatChatInsert;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  const CreateChatChatInsert({
    required this.id,
  });
}

@immutable
class CreateChatData {
  final CreateChatChatInsert chat_insert;
  CreateChatData.fromJson(dynamic json):
  
  chat_insert = CreateChatChatInsert.fromJson(json['chat_insert']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateChatData otherTyped = other as CreateChatData;
    return chat_insert == otherTyped.chat_insert;
    
  }
  @override
  int get hashCode => chat_insert.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['chat_insert'] = chat_insert.toJson();
    return json;
  }

  const CreateChatData({
    required this.chat_insert,
  });
}

@immutable
class CreateChatVariables {
  final bool isGroup;
  late final Optional<String>name;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  CreateChatVariables.fromJson(Map<String, dynamic> json):
  
  isGroup = nativeFromJson<bool>(json['isGroup']) {
  
  
  
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

    final CreateChatVariables otherTyped = other as CreateChatVariables;
    return isGroup == otherTyped.isGroup && 
    name == otherTyped.name;
    
  }
  @override
  int get hashCode => Object.hashAll([isGroup.hashCode, name.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['isGroup'] = nativeToJson<bool>(isGroup);
    if(name.state == OptionalState.set) {
      json['name'] = name.toJson();
    }
    return json;
  }

  const CreateChatVariables({
    required this.isGroup,
    required this.name,
  });
}

