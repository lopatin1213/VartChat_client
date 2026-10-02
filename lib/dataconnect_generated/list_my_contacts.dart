part of 'generated.dart';

class ListMyContactsVariablesBuilder {
  
  final FirebaseDataConnect _dataConnect;
  ListMyContactsVariablesBuilder(this._dataConnect, );
  Deserializer<ListMyContactsData> dataDeserializer = (dynamic json)  => ListMyContactsData.fromJson(jsonDecode(json));
  
  Future<QueryResult<ListMyContactsData, void>> execute({QueryFetchPolicy fetchPolicy = QueryFetchPolicy.preferCache}) {
    return ref().execute(fetchPolicy: fetchPolicy);
  }

  QueryRef<ListMyContactsData, void> ref() {
    
    return _dataConnect.query("ListMyContacts", dataDeserializer, emptySerializer, null);
  }
}

@immutable
class ListMyContactsContacts {
  final ListMyContactsContactsContactUser contactUser;
  ListMyContactsContacts.fromJson(dynamic json):
  
  contactUser = ListMyContactsContactsContactUser.fromJson(json['contactUser']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListMyContactsContacts otherTyped = other as ListMyContactsContacts;
    return contactUser == otherTyped.contactUser;
    
  }
  @override
  int get hashCode => contactUser.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['contactUser'] = contactUser.toJson();
    return json;
  }

  const ListMyContactsContacts({
    required this.contactUser,
  });
}

@immutable
class ListMyContactsContactsContactUser {
  final String username;
  final String email;
  ListMyContactsContactsContactUser.fromJson(dynamic json):
  
  username = nativeFromJson<String>(json['username']),
  email = nativeFromJson<String>(json['email']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListMyContactsContactsContactUser otherTyped = other as ListMyContactsContactsContactUser;
    return username == otherTyped.username && 
    email == otherTyped.email;
    
  }
  @override
  int get hashCode => Object.hashAll([username.hashCode, email.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['username'] = nativeToJson<String>(username);
    json['email'] = nativeToJson<String>(email);
    return json;
  }

  const ListMyContactsContactsContactUser({
    required this.username,
    required this.email,
  });
}

@immutable
class ListMyContactsData {
  final List<ListMyContactsContacts> contacts;
  ListMyContactsData.fromJson(dynamic json):
  
  contacts = (json['contacts'] as List<dynamic>)
        .map((e) => ListMyContactsContacts.fromJson(e))
        .toList();
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListMyContactsData otherTyped = other as ListMyContactsData;
    return contacts == otherTyped.contacts;
    
  }
  @override
  int get hashCode => contacts.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['contacts'] = contacts.map((e) => e.toJson()).toList();
    return json;
  }

  const ListMyContactsData({
    required this.contacts,
  });
}

