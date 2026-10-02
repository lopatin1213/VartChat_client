part of 'generated.dart';

class ListChatsVariablesBuilder {
  
  final FirebaseDataConnect _dataConnect;
  ListChatsVariablesBuilder(this._dataConnect, );
  Deserializer<ListChatsData> dataDeserializer = (dynamic json)  => ListChatsData.fromJson(jsonDecode(json));
  
  Future<QueryResult<ListChatsData, void>> execute({QueryFetchPolicy fetchPolicy = QueryFetchPolicy.preferCache}) {
    return ref().execute(fetchPolicy: fetchPolicy);
  }

  QueryRef<ListChatsData, void> ref() {
    
    return _dataConnect.query("ListChats", dataDeserializer, emptySerializer, null);
  }
}

@immutable
class ListChatsChats {
  final String? name;
  final Timestamp createdAt;
  ListChatsChats.fromJson(dynamic json):
  
  name = json['name'] == null ? null : nativeFromJson<String>(json['name']),
  createdAt = Timestamp.fromJson(json['createdAt']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListChatsChats otherTyped = other as ListChatsChats;
    return name == otherTyped.name && 
    createdAt == otherTyped.createdAt;
    
  }
  @override
  int get hashCode => Object.hashAll([name.hashCode, createdAt.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (name != null) {
      json['name'] = nativeToJson<String?>(name);
    }
    json['createdAt'] = createdAt.toJson();
    return json;
  }

  const ListChatsChats({
    this.name,
    required this.createdAt,
  });
}

@immutable
class ListChatsData {
  final List<ListChatsChats> chats;
  ListChatsData.fromJson(dynamic json):
  
  chats = (json['chats'] as List<dynamic>)
        .map((e) => ListChatsChats.fromJson(e))
        .toList();
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListChatsData otherTyped = other as ListChatsData;
    return chats == otherTyped.chats;
    
  }
  @override
  int get hashCode => chats.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['chats'] = chats.map((e) => e.toJson()).toList();
    return json;
  }

  const ListChatsData({
    required this.chats,
  });
}

