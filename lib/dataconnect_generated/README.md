# dataconnect_generated SDK

## Installation
```sh
flutter pub get firebase_data_connect
flutterfire configure
```
For more information, see [Flutter for Firebase installation documentation](https://firebase.google.com/docs/data-connect/flutter-sdk#use-core).

## Data Connect instance
Each connector creates a static class, with an instance of the `DataConnect` class that can be used to connect to your Data Connect backend and call operations.

### Connecting to the emulator

```dart
String host = 'localhost'; // or your host name
int port = 9399; // or your port number
ExampleConnector.instance.dataConnect.useDataConnectEmulator(host, port);
```

You can also call queries and mutations by using the connector class.
## Queries

### GetUser
#### Required Arguments
```dart
// No required arguments
ExampleConnector.instance.getUser().execute();
```



#### Return Type
`execute()` returns a `QueryResult<GetUserData, void>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

/// Result of a query request. Created to hold extra variables in the future.
class QueryResult<Data, Variables> extends OperationResult<Data, Variables> {
  QueryResult(super.dataConnect, super.data, super.ref);
}

final result = await ExampleConnector.instance.getUser();
GetUserData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
final ref = ExampleConnector.instance.getUser().ref();
ref.execute();

ref.subscribe(...);
```


### ListUsers
#### Required Arguments
```dart
// No required arguments
ExampleConnector.instance.listUsers().execute();
```



#### Return Type
`execute()` returns a `QueryResult<ListUsersData, void>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

/// Result of a query request. Created to hold extra variables in the future.
class QueryResult<Data, Variables> extends OperationResult<Data, Variables> {
  QueryResult(super.dataConnect, super.data, super.ref);
}

final result = await ExampleConnector.instance.listUsers();
ListUsersData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
final ref = ExampleConnector.instance.listUsers().ref();
ref.execute();

ref.subscribe(...);
```


### GetChat
#### Required Arguments
```dart
String id = ...;
ExampleConnector.instance.getChat(
  id: id,
).execute();
```



#### Return Type
`execute()` returns a `QueryResult<GetChatData, GetChatVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

/// Result of a query request. Created to hold extra variables in the future.
class QueryResult<Data, Variables> extends OperationResult<Data, Variables> {
  QueryResult(super.dataConnect, super.data, super.ref);
}

final result = await ExampleConnector.instance.getChat(
  id: id,
);
GetChatData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String id = ...;

final ref = ExampleConnector.instance.getChat(
  id: id,
).ref();
ref.execute();

ref.subscribe(...);
```


### ListChats
#### Required Arguments
```dart
// No required arguments
ExampleConnector.instance.listChats().execute();
```



#### Return Type
`execute()` returns a `QueryResult<ListChatsData, void>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

/// Result of a query request. Created to hold extra variables in the future.
class QueryResult<Data, Variables> extends OperationResult<Data, Variables> {
  QueryResult(super.dataConnect, super.data, super.ref);
}

final result = await ExampleConnector.instance.listChats();
ListChatsData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
final ref = ExampleConnector.instance.listChats().ref();
ref.execute();

ref.subscribe(...);
```


### GetChatParticipant
#### Required Arguments
```dart
String id = ...;
ExampleConnector.instance.getChatParticipant(
  id: id,
).execute();
```



#### Return Type
`execute()` returns a `QueryResult<GetChatParticipantData, GetChatParticipantVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

/// Result of a query request. Created to hold extra variables in the future.
class QueryResult<Data, Variables> extends OperationResult<Data, Variables> {
  QueryResult(super.dataConnect, super.data, super.ref);
}

final result = await ExampleConnector.instance.getChatParticipant(
  id: id,
);
GetChatParticipantData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String id = ...;

final ref = ExampleConnector.instance.getChatParticipant(
  id: id,
).ref();
ref.execute();

ref.subscribe(...);
```


### ListChatParticipants
#### Required Arguments
```dart
String chatId = ...;
ExampleConnector.instance.listChatParticipants(
  chatId: chatId,
).execute();
```



#### Return Type
`execute()` returns a `QueryResult<ListChatParticipantsData, ListChatParticipantsVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

/// Result of a query request. Created to hold extra variables in the future.
class QueryResult<Data, Variables> extends OperationResult<Data, Variables> {
  QueryResult(super.dataConnect, super.data, super.ref);
}

final result = await ExampleConnector.instance.listChatParticipants(
  chatId: chatId,
);
ListChatParticipantsData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String chatId = ...;

final ref = ExampleConnector.instance.listChatParticipants(
  chatId: chatId,
).ref();
ref.execute();

ref.subscribe(...);
```


### GetMessage
#### Required Arguments
```dart
String id = ...;
ExampleConnector.instance.getMessage(
  id: id,
).execute();
```



#### Return Type
`execute()` returns a `QueryResult<GetMessageData, GetMessageVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

/// Result of a query request. Created to hold extra variables in the future.
class QueryResult<Data, Variables> extends OperationResult<Data, Variables> {
  QueryResult(super.dataConnect, super.data, super.ref);
}

final result = await ExampleConnector.instance.getMessage(
  id: id,
);
GetMessageData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String id = ...;

final ref = ExampleConnector.instance.getMessage(
  id: id,
).ref();
ref.execute();

ref.subscribe(...);
```


### ListMessages
#### Required Arguments
```dart
String chatId = ...;
ExampleConnector.instance.listMessages(
  chatId: chatId,
).execute();
```



#### Return Type
`execute()` returns a `QueryResult<ListMessagesData, ListMessagesVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

/// Result of a query request. Created to hold extra variables in the future.
class QueryResult<Data, Variables> extends OperationResult<Data, Variables> {
  QueryResult(super.dataConnect, super.data, super.ref);
}

final result = await ExampleConnector.instance.listMessages(
  chatId: chatId,
);
ListMessagesData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String chatId = ...;

final ref = ExampleConnector.instance.listMessages(
  chatId: chatId,
).ref();
ref.execute();

ref.subscribe(...);
```


### GetContact
#### Required Arguments
```dart
String id = ...;
ExampleConnector.instance.getContact(
  id: id,
).execute();
```



#### Return Type
`execute()` returns a `QueryResult<GetContactData, GetContactVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

/// Result of a query request. Created to hold extra variables in the future.
class QueryResult<Data, Variables> extends OperationResult<Data, Variables> {
  QueryResult(super.dataConnect, super.data, super.ref);
}

final result = await ExampleConnector.instance.getContact(
  id: id,
);
GetContactData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String id = ...;

final ref = ExampleConnector.instance.getContact(
  id: id,
).ref();
ref.execute();

ref.subscribe(...);
```


### ListMyContacts
#### Required Arguments
```dart
// No required arguments
ExampleConnector.instance.listMyContacts().execute();
```



#### Return Type
`execute()` returns a `QueryResult<ListMyContactsData, void>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

/// Result of a query request. Created to hold extra variables in the future.
class QueryResult<Data, Variables> extends OperationResult<Data, Variables> {
  QueryResult(super.dataConnect, super.data, super.ref);
}

final result = await ExampleConnector.instance.listMyContacts();
ListMyContactsData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
final ref = ExampleConnector.instance.listMyContacts().ref();
ref.execute();

ref.subscribe(...);
```

## Mutations

### CreateUser
#### Required Arguments
```dart
String username = ...;
String email = ...;
ExampleConnector.instance.createUser(
  username: username,
  email: email,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<CreateUserData, CreateUserVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.createUser(
  username: username,
  email: email,
);
CreateUserData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String username = ...;
String email = ...;

final ref = ExampleConnector.instance.createUser(
  username: username,
  email: email,
).ref();
ref.execute();
```


### UpdateUser
#### Required Arguments
```dart
// No required arguments
ExampleConnector.instance.updateUser().execute();
```

#### Optional Arguments
We return a builder for each query. For UpdateUser, we created `UpdateUserBuilder`. For queries and mutations with optional parameters, we return a builder class.
The builder pattern allows Data Connect to distinguish between fields that haven't been set and fields that have been set to null. A field can be set by calling its respective setter method like below:
```dart
class UpdateUserVariablesBuilder {
  ...
 
  UpdateUserVariablesBuilder username(String? t) {
   _username.value = t;
   return this;
  }

  ...
}
ExampleConnector.instance.updateUser()
.username(username)
.execute();
```

#### Return Type
`execute()` returns a `OperationResult<UpdateUserData, UpdateUserVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.updateUser();
UpdateUserData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
final ref = ExampleConnector.instance.updateUser().ref();
ref.execute();
```


### DeleteUser
#### Required Arguments
```dart
// No required arguments
ExampleConnector.instance.deleteUser().execute();
```



#### Return Type
`execute()` returns a `OperationResult<DeleteUserData, void>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.deleteUser();
DeleteUserData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
final ref = ExampleConnector.instance.deleteUser().ref();
ref.execute();
```


### CreateChat
#### Required Arguments
```dart
bool isGroup = ...;
ExampleConnector.instance.createChat(
  isGroup: isGroup,
).execute();
```

#### Optional Arguments
We return a builder for each query. For CreateChat, we created `CreateChatBuilder`. For queries and mutations with optional parameters, we return a builder class.
The builder pattern allows Data Connect to distinguish between fields that haven't been set and fields that have been set to null. A field can be set by calling its respective setter method like below:
```dart
class CreateChatVariablesBuilder {
  ...
   CreateChatVariablesBuilder name(String? t) {
   _name.value = t;
   return this;
  }

  ...
}
ExampleConnector.instance.createChat(
  isGroup: isGroup,
)
.name(name)
.execute();
```

#### Return Type
`execute()` returns a `OperationResult<CreateChatData, CreateChatVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.createChat(
  isGroup: isGroup,
);
CreateChatData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
bool isGroup = ...;

final ref = ExampleConnector.instance.createChat(
  isGroup: isGroup,
).ref();
ref.execute();
```


### UpdateChat
#### Required Arguments
```dart
String id = ...;
ExampleConnector.instance.updateChat(
  id: id,
).execute();
```

#### Optional Arguments
We return a builder for each query. For UpdateChat, we created `UpdateChatBuilder`. For queries and mutations with optional parameters, we return a builder class.
The builder pattern allows Data Connect to distinguish between fields that haven't been set and fields that have been set to null. A field can be set by calling its respective setter method like below:
```dart
class UpdateChatVariablesBuilder {
  ...
   UpdateChatVariablesBuilder name(String? t) {
   _name.value = t;
   return this;
  }

  ...
}
ExampleConnector.instance.updateChat(
  id: id,
)
.name(name)
.execute();
```

#### Return Type
`execute()` returns a `OperationResult<UpdateChatData, UpdateChatVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.updateChat(
  id: id,
);
UpdateChatData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String id = ...;

final ref = ExampleConnector.instance.updateChat(
  id: id,
).ref();
ref.execute();
```


### DeleteChat
#### Required Arguments
```dart
String id = ...;
ExampleConnector.instance.deleteChat(
  id: id,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<DeleteChatData, DeleteChatVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.deleteChat(
  id: id,
);
DeleteChatData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String id = ...;

final ref = ExampleConnector.instance.deleteChat(
  id: id,
).ref();
ref.execute();
```


### CreateChatParticipant
#### Required Arguments
```dart
String chatId = ...;
ExampleConnector.instance.createChatParticipant(
  chatId: chatId,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<CreateChatParticipantData, CreateChatParticipantVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.createChatParticipant(
  chatId: chatId,
);
CreateChatParticipantData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String chatId = ...;

final ref = ExampleConnector.instance.createChatParticipant(
  chatId: chatId,
).ref();
ref.execute();
```


### UpdateChatParticipant
#### Required Arguments
```dart
String id = ...;
Timestamp joinedAt = ...;
ExampleConnector.instance.updateChatParticipant(
  id: id,
  joinedAt: joinedAt,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<UpdateChatParticipantData, UpdateChatParticipantVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.updateChatParticipant(
  id: id,
  joinedAt: joinedAt,
);
UpdateChatParticipantData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String id = ...;
Timestamp joinedAt = ...;

final ref = ExampleConnector.instance.updateChatParticipant(
  id: id,
  joinedAt: joinedAt,
).ref();
ref.execute();
```


### DeleteChatParticipant
#### Required Arguments
```dart
String id = ...;
ExampleConnector.instance.deleteChatParticipant(
  id: id,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<DeleteChatParticipantData, DeleteChatParticipantVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.deleteChatParticipant(
  id: id,
);
DeleteChatParticipantData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String id = ...;

final ref = ExampleConnector.instance.deleteChatParticipant(
  id: id,
).ref();
ref.execute();
```


### CreateMessage
#### Required Arguments
```dart
String chatId = ...;
String content = ...;
ExampleConnector.instance.createMessage(
  chatId: chatId,
  content: content,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<CreateMessageData, CreateMessageVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.createMessage(
  chatId: chatId,
  content: content,
);
CreateMessageData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String chatId = ...;
String content = ...;

final ref = ExampleConnector.instance.createMessage(
  chatId: chatId,
  content: content,
).ref();
ref.execute();
```


### UpdateMessage
#### Required Arguments
```dart
String id = ...;
ExampleConnector.instance.updateMessage(
  id: id,
).execute();
```

#### Optional Arguments
We return a builder for each query. For UpdateMessage, we created `UpdateMessageBuilder`. For queries and mutations with optional parameters, we return a builder class.
The builder pattern allows Data Connect to distinguish between fields that haven't been set and fields that have been set to null. A field can be set by calling its respective setter method like below:
```dart
class UpdateMessageVariablesBuilder {
  ...
   UpdateMessageVariablesBuilder content(String? t) {
   _content.value = t;
   return this;
  }

  ...
}
ExampleConnector.instance.updateMessage(
  id: id,
)
.content(content)
.execute();
```

#### Return Type
`execute()` returns a `OperationResult<UpdateMessageData, UpdateMessageVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.updateMessage(
  id: id,
);
UpdateMessageData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String id = ...;

final ref = ExampleConnector.instance.updateMessage(
  id: id,
).ref();
ref.execute();
```


### DeleteMessage
#### Required Arguments
```dart
String id = ...;
ExampleConnector.instance.deleteMessage(
  id: id,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<DeleteMessageData, DeleteMessageVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.deleteMessage(
  id: id,
);
DeleteMessageData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String id = ...;

final ref = ExampleConnector.instance.deleteMessage(
  id: id,
).ref();
ref.execute();
```


### CreateContact
#### Required Arguments
```dart
String contactUserId = ...;
ExampleConnector.instance.createContact(
  contactUserId: contactUserId,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<CreateContactData, CreateContactVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.createContact(
  contactUserId: contactUserId,
);
CreateContactData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String contactUserId = ...;

final ref = ExampleConnector.instance.createContact(
  contactUserId: contactUserId,
).ref();
ref.execute();
```


### DeleteContact
#### Required Arguments
```dart
String id = ...;
ExampleConnector.instance.deleteContact(
  id: id,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<DeleteContactData, DeleteContactVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.deleteContact(
  id: id,
);
DeleteContactData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String id = ...;

final ref = ExampleConnector.instance.deleteContact(
  id: id,
).ref();
ref.execute();
```

