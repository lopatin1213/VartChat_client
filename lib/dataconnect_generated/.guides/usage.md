# Basic Usage

```dart
ExampleConnector.instance.CreateUser(createUserVariables).execute();
ExampleConnector.instance.UpdateUser(updateUserVariables).execute();
ExampleConnector.instance.DeleteUser().execute();
ExampleConnector.instance.GetUser().execute();
ExampleConnector.instance.ListUsers().execute();
ExampleConnector.instance.CreateChat(createChatVariables).execute();
ExampleConnector.instance.UpdateChat(updateChatVariables).execute();
ExampleConnector.instance.DeleteChat(deleteChatVariables).execute();
ExampleConnector.instance.GetChat(getChatVariables).execute();
ExampleConnector.instance.ListChats().execute();

```

## Optional Fields

Some operations may have optional fields. In these cases, the Flutter SDK exposes a builder method, and will have to be set separately.

Optional fields can be discovered based on classes that have `Optional` object types.

This is an example of a mutation with an optional field:

```dart
await ExampleConnector.instance.UpdateMessage({ ... })
.content(...)
.execute();
```

Note: the above example is a mutation, but the same logic applies to query operations as well. Additionally, `createMovie` is an example, and may not be available to the user.

