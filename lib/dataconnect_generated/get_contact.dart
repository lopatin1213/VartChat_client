part of 'generated.dart';

class GetContactVariablesBuilder {
  String id;

  final FirebaseDataConnect _dataConnect;
  GetContactVariablesBuilder(this._dataConnect, {required  this.id,});
  Deserializer<GetContactData> dataDeserializer = (dynamic json)  => GetContactData.fromJson(jsonDecode(json));
  Serializer<GetContactVariables> varsSerializer = (GetContactVariables vars) => jsonEncode(vars.toJson());
  Future<QueryResult<GetContactData, GetContactVariables>> execute({QueryFetchPolicy fetchPolicy = QueryFetchPolicy.preferCache}) {
    return ref().execute(fetchPolicy: fetchPolicy);
  }

  QueryRef<GetContactData, GetContactVariables> ref() {
    GetContactVariables vars= GetContactVariables(id: id,);
    return _dataConnect.query("GetContact", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class GetContactContact {
  final GetContactContactContactUser contactUser;
  GetContactContact.fromJson(dynamic json):
  
  contactUser = GetContactContactContactUser.fromJson(json['contactUser']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetContactContact otherTyped = other as GetContactContact;
    return contactUser == otherTyped.contactUser;
    
  }
  @override
  int get hashCode => contactUser.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['contactUser'] = contactUser.toJson();
    return json;
  }

  const GetContactContact({
    required this.contactUser,
  });
}

@immutable
class GetContactContactContactUser {
  final String username;
  GetContactContactContactUser.fromJson(dynamic json):
  
  username = nativeFromJson<String>(json['username']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetContactContactContactUser otherTyped = other as GetContactContactContactUser;
    return username == otherTyped.username;
    
  }
  @override
  int get hashCode => username.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['username'] = nativeToJson<String>(username);
    return json;
  }

  const GetContactContactContactUser({
    required this.username,
  });
}

@immutable
class GetContactData {
  final GetContactContact? contact;
  GetContactData.fromJson(dynamic json):
  
  contact = json['contact'] == null ? null : GetContactContact.fromJson(json['contact']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetContactData otherTyped = other as GetContactData;
    return contact == otherTyped.contact;
    
  }
  @override
  int get hashCode => contact.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (contact != null) {
      json['contact'] = contact!.toJson();
    }
    return json;
  }

  const GetContactData({
    this.contact,
  });
}

@immutable
class GetContactVariables {
  final String id;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  GetContactVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetContactVariables otherTyped = other as GetContactVariables;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  const GetContactVariables({
    required this.id,
  });
}

