// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChatMessageAdapter extends TypeAdapter<ChatMessage> {
  @override
  final int typeId = 0;

  @override
  ChatMessage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatMessage(
      id: fields[0] as int,
      sender: fields[1] as String,
      recipient: fields[2] as String,
      text: fields[3] as String,
      isMe: fields[4] as bool,
      timestamp: fields[5] as DateTime,
      readStatus: fields[6] as int,
      replyToId: fields[7] as int,
      readMe: fields[8] as bool,
      readAny: fields[9] as bool,
      views: fields[10] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, ChatMessage obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.sender)
      ..writeByte(2)
      ..write(obj.recipient)
      ..writeByte(3)
      ..write(obj.text)
      ..writeByte(4)
      ..write(obj.isMe)
      ..writeByte(5)
      ..write(obj.timestamp)
      ..writeByte(6)
      ..write(obj.readStatus)
      ..writeByte(7)
      ..write(obj.replyToId)
      ..writeByte(8)
      ..write(obj.readMe)
      ..writeByte(9)
      ..write(obj.readAny)
      ..writeByte(10)
      ..write(obj.views);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
