part of 'generated.dart';

class DeleteContactVariablesBuilder {
  String id;

  final FirebaseDataConnect _dataConnect;
  DeleteContactVariablesBuilder(this._dataConnect, {required  this.id,});
  Deserializer<DeleteContactData> dataDeserializer = (dynamic json)  => DeleteContactData.fromJson(jsonDecode(json));
  Serializer<DeleteContactVariables> varsSerializer = (DeleteContactVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<DeleteContactData, DeleteContactVariables>> execute() {
    return ref().execute();
  }

  MutationRef<DeleteContactData, DeleteContactVariables> ref() {
    DeleteContactVariables vars= DeleteContactVariables(id: id,);
    return _dataConnect.mutation("DeleteContact", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class DeleteContactContactDelete {
  final String id;
  DeleteContactContactDelete.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteContactContactDelete otherTyped = other as DeleteContactContactDelete;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  const DeleteContactContactDelete({
    required this.id,
  });
}

@immutable
class DeleteContactData {
  final DeleteContactContactDelete? contact_delete;
  DeleteContactData.fromJson(dynamic json):
  
  contact_delete = json['contact_delete'] == null ? null : DeleteContactContactDelete.fromJson(json['contact_delete']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteContactData otherTyped = other as DeleteContactData;
    return contact_delete == otherTyped.contact_delete;
    
  }
  @override
  int get hashCode => contact_delete.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (contact_delete != null) {
      json['contact_delete'] = contact_delete!.toJson();
    }
    return json;
  }

  const DeleteContactData({
    this.contact_delete,
  });
}

@immutable
class DeleteContactVariables {
  final String id;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  DeleteContactVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteContactVariables otherTyped = other as DeleteContactVariables;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  const DeleteContactVariables({
    required this.id,
  });
}

