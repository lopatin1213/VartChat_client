part of 'generated.dart';

class CreateContactVariablesBuilder {
  String contactUserId;

  final FirebaseDataConnect _dataConnect;
  CreateContactVariablesBuilder(this._dataConnect, {required  this.contactUserId,});
  Deserializer<CreateContactData> dataDeserializer = (dynamic json)  => CreateContactData.fromJson(jsonDecode(json));
  Serializer<CreateContactVariables> varsSerializer = (CreateContactVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<CreateContactData, CreateContactVariables>> execute() {
    return ref().execute();
  }

  MutationRef<CreateContactData, CreateContactVariables> ref() {
    CreateContactVariables vars= CreateContactVariables(contactUserId: contactUserId,);
    return _dataConnect.mutation("CreateContact", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class CreateContactContactInsert {
  final String id;
  CreateContactContactInsert.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateContactContactInsert otherTyped = other as CreateContactContactInsert;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  const CreateContactContactInsert({
    required this.id,
  });
}

@immutable
class CreateContactData {
  final CreateContactContactInsert contact_insert;
  CreateContactData.fromJson(dynamic json):
  
  contact_insert = CreateContactContactInsert.fromJson(json['contact_insert']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateContactData otherTyped = other as CreateContactData;
    return contact_insert == otherTyped.contact_insert;
    
  }
  @override
  int get hashCode => contact_insert.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['contact_insert'] = contact_insert.toJson();
    return json;
  }

  const CreateContactData({
    required this.contact_insert,
  });
}

@immutable
class CreateContactVariables {
  final String contactUserId;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  CreateContactVariables.fromJson(Map<String, dynamic> json):
  
  contactUserId = nativeFromJson<String>(json['contactUserId']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateContactVariables otherTyped = other as CreateContactVariables;
    return contactUserId == otherTyped.contactUserId;
    
  }
  @override
  int get hashCode => contactUserId.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['contactUserId'] = nativeToJson<String>(contactUserId);
    return json;
  }

  const CreateContactVariables({
    required this.contactUserId,
  });
}

