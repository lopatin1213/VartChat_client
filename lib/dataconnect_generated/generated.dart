library;
import 'package:firebase_data_connect/firebase_data_connect.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

part 'create_user.dart';

part 'update_user.dart';

part 'delete_user.dart';

part 'get_user.dart';

part 'list_users.dart';

part 'create_chat.dart';

part 'update_chat.dart';

part 'delete_chat.dart';

part 'get_chat.dart';

part 'list_chats.dart';

part 'create_chat_participant.dart';

part 'update_chat_participant.dart';

part 'delete_chat_participant.dart';

part 'get_chat_participant.dart';

part 'list_chat_participants.dart';

part 'create_message.dart';

part 'update_message.dart';

part 'delete_message.dart';

part 'get_message.dart';

part 'list_messages.dart';

part 'create_contact.dart';

part 'delete_contact.dart';

part 'get_contact.dart';

part 'list_my_contacts.dart';







class ExampleConnector {
  
  
  CreateUserVariablesBuilder createUser ({required String username, required String email, }) {
    return CreateUserVariablesBuilder(dataConnect, username: username,email: email,);
  }
  
  
  UpdateUserVariablesBuilder updateUser () {
    return UpdateUserVariablesBuilder(dataConnect, );
  }
  
  
  DeleteUserVariablesBuilder deleteUser () {
    return DeleteUserVariablesBuilder(dataConnect, );
  }
  
  
  GetUserVariablesBuilder getUser () {
    return GetUserVariablesBuilder(dataConnect, );
  }
  
  
  ListUsersVariablesBuilder listUsers () {
    return ListUsersVariablesBuilder(dataConnect, );
  }
  
  
  CreateChatVariablesBuilder createChat ({required bool isGroup, }) {
    return CreateChatVariablesBuilder(dataConnect, isGroup: isGroup,);
  }
  
  
  UpdateChatVariablesBuilder updateChat ({required String id, }) {
    return UpdateChatVariablesBuilder(dataConnect, id: id,);
  }
  
  
  DeleteChatVariablesBuilder deleteChat ({required String id, }) {
    return DeleteChatVariablesBuilder(dataConnect, id: id,);
  }
  
  
  GetChatVariablesBuilder getChat ({required String id, }) {
    return GetChatVariablesBuilder(dataConnect, id: id,);
  }
  
  
  ListChatsVariablesBuilder listChats () {
    return ListChatsVariablesBuilder(dataConnect, );
  }
  
  
  CreateChatParticipantVariablesBuilder createChatParticipant ({required String chatId, }) {
    return CreateChatParticipantVariablesBuilder(dataConnect, chatId: chatId,);
  }
  
  
  UpdateChatParticipantVariablesBuilder updateChatParticipant ({required String id, required Timestamp joinedAt, }) {
    return UpdateChatParticipantVariablesBuilder(dataConnect, id: id,joinedAt: joinedAt,);
  }
  
  
  DeleteChatParticipantVariablesBuilder deleteChatParticipant ({required String id, }) {
    return DeleteChatParticipantVariablesBuilder(dataConnect, id: id,);
  }
  
  
  GetChatParticipantVariablesBuilder getChatParticipant ({required String id, }) {
    return GetChatParticipantVariablesBuilder(dataConnect, id: id,);
  }
  
  
  ListChatParticipantsVariablesBuilder listChatParticipants ({required String chatId, }) {
    return ListChatParticipantsVariablesBuilder(dataConnect, chatId: chatId,);
  }
  
  
  CreateMessageVariablesBuilder createMessage ({required String chatId, required String content, }) {
    return CreateMessageVariablesBuilder(dataConnect, chatId: chatId,content: content,);
  }
  
  
  UpdateMessageVariablesBuilder updateMessage ({required String id, }) {
    return UpdateMessageVariablesBuilder(dataConnect, id: id,);
  }
  
  
  DeleteMessageVariablesBuilder deleteMessage ({required String id, }) {
    return DeleteMessageVariablesBuilder(dataConnect, id: id,);
  }
  
  
  GetMessageVariablesBuilder getMessage ({required String id, }) {
    return GetMessageVariablesBuilder(dataConnect, id: id,);
  }
  
  
  ListMessagesVariablesBuilder listMessages ({required String chatId, }) {
    return ListMessagesVariablesBuilder(dataConnect, chatId: chatId,);
  }
  
  
  CreateContactVariablesBuilder createContact ({required String contactUserId, }) {
    return CreateContactVariablesBuilder(dataConnect, contactUserId: contactUserId,);
  }
  
  
  DeleteContactVariablesBuilder deleteContact ({required String id, }) {
    return DeleteContactVariablesBuilder(dataConnect, id: id,);
  }
  
  
  GetContactVariablesBuilder getContact ({required String id, }) {
    return GetContactVariablesBuilder(dataConnect, id: id,);
  }
  
  
  ListMyContactsVariablesBuilder listMyContacts () {
    return ListMyContactsVariablesBuilder(dataConnect, );
  }
  

  static ConnectorConfig connectorConfig = ConnectorConfig(
    'us-east4',
    'example',
    'vartchat',
  );

  ExampleConnector({required this.dataConnect});
  static ExampleConnector get instance {
    
    CacheSettings cacheSettings = CacheSettings(
      maxAge: Duration(milliseconds:0),
      storage: CacheStorage.persistent,
    );
    
    return ExampleConnector(
        dataConnect: FirebaseDataConnect.instanceFor(
            connectorConfig: connectorConfig,
            
            cacheSettings: cacheSettings,
            
            sdkType: CallerSDKType.generated));
  }

  FirebaseDataConnect dataConnect;
}
