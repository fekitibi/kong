// Code generated by protoc-gen-go. DO NOT EDIT.
// versions:
// 	protoc-gen-go v1.36.1
// 	protoc        v5.29.2
// source: targetservice.proto

package targetservice

import (
	timestamp "github.com/golang/protobuf/ptypes/timestamp"
	_ "google.golang.org/genproto/googleapis/api/annotations"
	protoreflect "google.golang.org/protobuf/reflect/protoreflect"
	protoimpl "google.golang.org/protobuf/runtime/protoimpl"
	reflect "reflect"
	sync "sync"
)

const (
	// Verify that this generated code is sufficiently up-to-date.
	_ = protoimpl.EnforceVersion(20 - protoimpl.MinVersion)
	// Verify that runtime/protoimpl is sufficiently up-to-date.
	_ = protoimpl.EnforceVersion(protoimpl.MaxVersion - 20)
)

type HelloRequest struct {
	state         protoimpl.MessageState `protogen:"open.v1"`
	Greeting      string                 `protobuf:"bytes,1,opt,name=greeting,proto3" json:"greeting,omitempty"`
	BooleanTest   bool                   `protobuf:"varint,2,opt,name=boolean_test,json=booleanTest,proto3" json:"boolean_test,omitempty"`
	unknownFields protoimpl.UnknownFields
	sizeCache     protoimpl.SizeCache
}

func (x *HelloRequest) Reset() {
	*x = HelloRequest{}
	mi := &file_targetservice_proto_msgTypes[0]
	ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
	ms.StoreMessageInfo(mi)
}

func (x *HelloRequest) String() string {
	return protoimpl.X.MessageStringOf(x)
}

func (*HelloRequest) ProtoMessage() {}

func (x *HelloRequest) ProtoReflect() protoreflect.Message {
	mi := &file_targetservice_proto_msgTypes[0]
	if x != nil {
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		if ms.LoadMessageInfo() == nil {
			ms.StoreMessageInfo(mi)
		}
		return ms
	}
	return mi.MessageOf(x)
}

// Deprecated: Use HelloRequest.ProtoReflect.Descriptor instead.
func (*HelloRequest) Descriptor() ([]byte, []int) {
	return file_targetservice_proto_rawDescGZIP(), []int{0}
}

func (x *HelloRequest) GetGreeting() string {
	if x != nil {
		return x.Greeting
	}
	return ""
}

func (x *HelloRequest) GetBooleanTest() bool {
	if x != nil {
		return x.BooleanTest
	}
	return false
}

type HelloResponse struct {
	state         protoimpl.MessageState `protogen:"open.v1"`
	Reply         string                 `protobuf:"bytes,1,opt,name=reply,proto3" json:"reply,omitempty"`
	BooleanTest   bool                   `protobuf:"varint,2,opt,name=boolean_test,json=booleanTest,proto3" json:"boolean_test,omitempty"`
	unknownFields protoimpl.UnknownFields
	sizeCache     protoimpl.SizeCache
}

func (x *HelloResponse) Reset() {
	*x = HelloResponse{}
	mi := &file_targetservice_proto_msgTypes[1]
	ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
	ms.StoreMessageInfo(mi)
}

func (x *HelloResponse) String() string {
	return protoimpl.X.MessageStringOf(x)
}

func (*HelloResponse) ProtoMessage() {}

func (x *HelloResponse) ProtoReflect() protoreflect.Message {
	mi := &file_targetservice_proto_msgTypes[1]
	if x != nil {
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		if ms.LoadMessageInfo() == nil {
			ms.StoreMessageInfo(mi)
		}
		return ms
	}
	return mi.MessageOf(x)
}

// Deprecated: Use HelloResponse.ProtoReflect.Descriptor instead.
func (*HelloResponse) Descriptor() ([]byte, []int) {
	return file_targetservice_proto_rawDescGZIP(), []int{1}
}

func (x *HelloResponse) GetReply() string {
	if x != nil {
		return x.Reply
	}
	return ""
}

func (x *HelloResponse) GetBooleanTest() bool {
	if x != nil {
		return x.BooleanTest
	}
	return false
}

type BallIn struct {
	state         protoimpl.MessageState `protogen:"open.v1"`
	Message       string                 `protobuf:"bytes,1,opt,name=message,proto3" json:"message,omitempty"`
	When          *timestamp.Timestamp   `protobuf:"bytes,2,opt,name=when,proto3" json:"when,omitempty"`
	Now           *timestamp.Timestamp   `protobuf:"bytes,3,opt,name=now,proto3" json:"now,omitempty"`
	unknownFields protoimpl.UnknownFields
	sizeCache     protoimpl.SizeCache
}

func (x *BallIn) Reset() {
	*x = BallIn{}
	mi := &file_targetservice_proto_msgTypes[2]
	ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
	ms.StoreMessageInfo(mi)
}

func (x *BallIn) String() string {
	return protoimpl.X.MessageStringOf(x)
}

func (*BallIn) ProtoMessage() {}

func (x *BallIn) ProtoReflect() protoreflect.Message {
	mi := &file_targetservice_proto_msgTypes[2]
	if x != nil {
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		if ms.LoadMessageInfo() == nil {
			ms.StoreMessageInfo(mi)
		}
		return ms
	}
	return mi.MessageOf(x)
}

// Deprecated: Use BallIn.ProtoReflect.Descriptor instead.
func (*BallIn) Descriptor() ([]byte, []int) {
	return file_targetservice_proto_rawDescGZIP(), []int{2}
}

func (x *BallIn) GetMessage() string {
	if x != nil {
		return x.Message
	}
	return ""
}

func (x *BallIn) GetWhen() *timestamp.Timestamp {
	if x != nil {
		return x.When
	}
	return nil
}

func (x *BallIn) GetNow() *timestamp.Timestamp {
	if x != nil {
		return x.Now
	}
	return nil
}

type BallOut struct {
	state         protoimpl.MessageState `protogen:"open.v1"`
	Reply         string                 `protobuf:"bytes,1,opt,name=reply,proto3" json:"reply,omitempty"`
	TimeMessage   string                 `protobuf:"bytes,2,opt,name=time_message,json=timeMessage,proto3" json:"time_message,omitempty"`
	Now           *timestamp.Timestamp   `protobuf:"bytes,3,opt,name=now,proto3" json:"now,omitempty"`
	unknownFields protoimpl.UnknownFields
	sizeCache     protoimpl.SizeCache
}

func (x *BallOut) Reset() {
	*x = BallOut{}
	mi := &file_targetservice_proto_msgTypes[3]
	ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
	ms.StoreMessageInfo(mi)
}

func (x *BallOut) String() string {
	return protoimpl.X.MessageStringOf(x)
}

func (*BallOut) ProtoMessage() {}

func (x *BallOut) ProtoReflect() protoreflect.Message {
	mi := &file_targetservice_proto_msgTypes[3]
	if x != nil {
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		if ms.LoadMessageInfo() == nil {
			ms.StoreMessageInfo(mi)
		}
		return ms
	}
	return mi.MessageOf(x)
}

// Deprecated: Use BallOut.ProtoReflect.Descriptor instead.
func (*BallOut) Descriptor() ([]byte, []int) {
	return file_targetservice_proto_rawDescGZIP(), []int{3}
}

func (x *BallOut) GetReply() string {
	if x != nil {
		return x.Reply
	}
	return ""
}

func (x *BallOut) GetTimeMessage() string {
	if x != nil {
		return x.TimeMessage
	}
	return ""
}

func (x *BallOut) GetNow() *timestamp.Timestamp {
	if x != nil {
		return x.Now
	}
	return nil
}

type Limb struct {
	state         protoimpl.MessageState `protogen:"open.v1"`
	Count         int32                  `protobuf:"varint,1,opt,name=count,proto3" json:"count,omitempty"`
	Endings       string                 `protobuf:"bytes,2,opt,name=endings,proto3" json:"endings,omitempty"`
	unknownFields protoimpl.UnknownFields
	sizeCache     protoimpl.SizeCache
}

func (x *Limb) Reset() {
	*x = Limb{}
	mi := &file_targetservice_proto_msgTypes[4]
	ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
	ms.StoreMessageInfo(mi)
}

func (x *Limb) String() string {
	return protoimpl.X.MessageStringOf(x)
}

func (*Limb) ProtoMessage() {}

func (x *Limb) ProtoReflect() protoreflect.Message {
	mi := &file_targetservice_proto_msgTypes[4]
	if x != nil {
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		if ms.LoadMessageInfo() == nil {
			ms.StoreMessageInfo(mi)
		}
		return ms
	}
	return mi.MessageOf(x)
}

// Deprecated: Use Limb.ProtoReflect.Descriptor instead.
func (*Limb) Descriptor() ([]byte, []int) {
	return file_targetservice_proto_rawDescGZIP(), []int{4}
}

func (x *Limb) GetCount() int32 {
	if x != nil {
		return x.Count
	}
	return 0
}

func (x *Limb) GetEndings() string {
	if x != nil {
		return x.Endings
	}
	return ""
}

type Body struct {
	state         protoimpl.MessageState `protogen:"open.v1"`
	Name          string                 `protobuf:"bytes,1,opt,name=name,proto3" json:"name,omitempty"`
	Hands         *Limb                  `protobuf:"bytes,2,opt,name=hands,proto3" json:"hands,omitempty"`
	Legs          *Limb                  `protobuf:"bytes,3,opt,name=legs,proto3" json:"legs,omitempty"`
	Tail          *Limb                  `protobuf:"bytes,4,opt,name=tail,proto3" json:"tail,omitempty"`
	unknownFields protoimpl.UnknownFields
	sizeCache     protoimpl.SizeCache
}

func (x *Body) Reset() {
	*x = Body{}
	mi := &file_targetservice_proto_msgTypes[5]
	ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
	ms.StoreMessageInfo(mi)
}

func (x *Body) String() string {
	return protoimpl.X.MessageStringOf(x)
}

func (*Body) ProtoMessage() {}

func (x *Body) ProtoReflect() protoreflect.Message {
	mi := &file_targetservice_proto_msgTypes[5]
	if x != nil {
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		if ms.LoadMessageInfo() == nil {
			ms.StoreMessageInfo(mi)
		}
		return ms
	}
	return mi.MessageOf(x)
}

// Deprecated: Use Body.ProtoReflect.Descriptor instead.
func (*Body) Descriptor() ([]byte, []int) {
	return file_targetservice_proto_rawDescGZIP(), []int{5}
}

func (x *Body) GetName() string {
	if x != nil {
		return x.Name
	}
	return ""
}

func (x *Body) GetHands() *Limb {
	if x != nil {
		return x.Hands
	}
	return nil
}

func (x *Body) GetLegs() *Limb {
	if x != nil {
		return x.Legs
	}
	return nil
}

func (x *Body) GetTail() *Limb {
	if x != nil {
		return x.Tail
	}
	return nil
}

type EchoMsg struct {
	state         protoimpl.MessageState `protogen:"open.v1"`
	Array         []string               `protobuf:"bytes,1,rep,name=array,proto3" json:"array,omitempty"`
	Nullable      string                 `protobuf:"bytes,2,opt,name=nullable,proto3" json:"nullable,omitempty"`
	unknownFields protoimpl.UnknownFields
	sizeCache     protoimpl.SizeCache
}

func (x *EchoMsg) Reset() {
	*x = EchoMsg{}
	mi := &file_targetservice_proto_msgTypes[6]
	ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
	ms.StoreMessageInfo(mi)
}

func (x *EchoMsg) String() string {
	return protoimpl.X.MessageStringOf(x)
}

func (*EchoMsg) ProtoMessage() {}

func (x *EchoMsg) ProtoReflect() protoreflect.Message {
	mi := &file_targetservice_proto_msgTypes[6]
	if x != nil {
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		if ms.LoadMessageInfo() == nil {
			ms.StoreMessageInfo(mi)
		}
		return ms
	}
	return mi.MessageOf(x)
}

// Deprecated: Use EchoMsg.ProtoReflect.Descriptor instead.
func (*EchoMsg) Descriptor() ([]byte, []int) {
	return file_targetservice_proto_rawDescGZIP(), []int{6}
}

func (x *EchoMsg) GetArray() []string {
	if x != nil {
		return x.Array
	}
	return nil
}

func (x *EchoMsg) GetNullable() string {
	if x != nil {
		return x.Nullable
	}
	return ""
}

type Headers struct {
	state         protoimpl.MessageState `protogen:"open.v1"`
	Headers       map[string]string      `protobuf:"bytes,1,rep,name=headers,proto3" json:"headers,omitempty" protobuf_key:"bytes,1,opt,name=key" protobuf_val:"bytes,2,opt,name=value"`
	unknownFields protoimpl.UnknownFields
	sizeCache     protoimpl.SizeCache
}

func (x *Headers) Reset() {
	*x = Headers{}
	mi := &file_targetservice_proto_msgTypes[7]
	ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
	ms.StoreMessageInfo(mi)
}

func (x *Headers) String() string {
	return protoimpl.X.MessageStringOf(x)
}

func (*Headers) ProtoMessage() {}

func (x *Headers) ProtoReflect() protoreflect.Message {
	mi := &file_targetservice_proto_msgTypes[7]
	if x != nil {
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		if ms.LoadMessageInfo() == nil {
			ms.StoreMessageInfo(mi)
		}
		return ms
	}
	return mi.MessageOf(x)
}

// Deprecated: Use Headers.ProtoReflect.Descriptor instead.
func (*Headers) Descriptor() ([]byte, []int) {
	return file_targetservice_proto_rawDescGZIP(), []int{7}
}

func (x *Headers) GetHeaders() map[string]string {
	if x != nil {
		return x.Headers
	}
	return nil
}

type Void struct {
	state         protoimpl.MessageState `protogen:"open.v1"`
	unknownFields protoimpl.UnknownFields
	sizeCache     protoimpl.SizeCache
}

func (x *Void) Reset() {
	*x = Void{}
	mi := &file_targetservice_proto_msgTypes[8]
	ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
	ms.StoreMessageInfo(mi)
}

func (x *Void) String() string {
	return protoimpl.X.MessageStringOf(x)
}

func (*Void) ProtoMessage() {}

func (x *Void) ProtoReflect() protoreflect.Message {
	mi := &file_targetservice_proto_msgTypes[8]
	if x != nil {
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		if ms.LoadMessageInfo() == nil {
			ms.StoreMessageInfo(mi)
		}
		return ms
	}
	return mi.MessageOf(x)
}

// Deprecated: Use Void.ProtoReflect.Descriptor instead.
func (*Void) Descriptor() ([]byte, []int) {
	return file_targetservice_proto_rawDescGZIP(), []int{8}
}

var File_targetservice_proto protoreflect.FileDescriptor

var file_targetservice_proto_rawDesc = []byte{
	0x0a, 0x13, 0x74, 0x61, 0x72, 0x67, 0x65, 0x74, 0x73, 0x65, 0x72, 0x76, 0x69, 0x63, 0x65, 0x2e,
	0x70, 0x72, 0x6f, 0x74, 0x6f, 0x12, 0x0d, 0x74, 0x61, 0x72, 0x67, 0x65, 0x74, 0x73, 0x65, 0x72,
	0x76, 0x69, 0x63, 0x65, 0x1a, 0x1c, 0x67, 0x6f, 0x6f, 0x67, 0x6c, 0x65, 0x2f, 0x61, 0x70, 0x69,
	0x2f, 0x61, 0x6e, 0x6e, 0x6f, 0x74, 0x61, 0x74, 0x69, 0x6f, 0x6e, 0x73, 0x2e, 0x70, 0x72, 0x6f,
	0x74, 0x6f, 0x1a, 0x1f, 0x67, 0x6f, 0x6f, 0x67, 0x6c, 0x65, 0x2f, 0x70, 0x72, 0x6f, 0x74, 0x6f,
	0x62, 0x75, 0x66, 0x2f, 0x74, 0x69, 0x6d, 0x65, 0x73, 0x74, 0x61, 0x6d, 0x70, 0x2e, 0x70, 0x72,
	0x6f, 0x74, 0x6f, 0x22, 0x4d, 0x0a, 0x0c, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x52, 0x65, 0x71, 0x75,
	0x65, 0x73, 0x74, 0x12, 0x1a, 0x0a, 0x08, 0x67, 0x72, 0x65, 0x65, 0x74, 0x69, 0x6e, 0x67, 0x18,
	0x01, 0x20, 0x01, 0x28, 0x09, 0x52, 0x08, 0x67, 0x72, 0x65, 0x65, 0x74, 0x69, 0x6e, 0x67, 0x12,
	0x21, 0x0a, 0x0c, 0x62, 0x6f, 0x6f, 0x6c, 0x65, 0x61, 0x6e, 0x5f, 0x74, 0x65, 0x73, 0x74, 0x18,
	0x02, 0x20, 0x01, 0x28, 0x08, 0x52, 0x0b, 0x62, 0x6f, 0x6f, 0x6c, 0x65, 0x61, 0x6e, 0x54, 0x65,
	0x73, 0x74, 0x22, 0x48, 0x0a, 0x0d, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x52, 0x65, 0x73, 0x70, 0x6f,
	0x6e, 0x73, 0x65, 0x12, 0x14, 0x0a, 0x05, 0x72, 0x65, 0x70, 0x6c, 0x79, 0x18, 0x01, 0x20, 0x01,
	0x28, 0x09, 0x52, 0x05, 0x72, 0x65, 0x70, 0x6c, 0x79, 0x12, 0x21, 0x0a, 0x0c, 0x62, 0x6f, 0x6f,
	0x6c, 0x65, 0x61, 0x6e, 0x5f, 0x74, 0x65, 0x73, 0x74, 0x18, 0x02, 0x20, 0x01, 0x28, 0x08, 0x52,
	0x0b, 0x62, 0x6f, 0x6f, 0x6c, 0x65, 0x61, 0x6e, 0x54, 0x65, 0x73, 0x74, 0x22, 0x80, 0x01, 0x0a,
	0x06, 0x42, 0x61, 0x6c, 0x6c, 0x49, 0x6e, 0x12, 0x18, 0x0a, 0x07, 0x6d, 0x65, 0x73, 0x73, 0x61,
	0x67, 0x65, 0x18, 0x01, 0x20, 0x01, 0x28, 0x09, 0x52, 0x07, 0x6d, 0x65, 0x73, 0x73, 0x61, 0x67,
	0x65, 0x12, 0x2e, 0x0a, 0x04, 0x77, 0x68, 0x65, 0x6e, 0x18, 0x02, 0x20, 0x01, 0x28, 0x0b, 0x32,
	0x1a, 0x2e, 0x67, 0x6f, 0x6f, 0x67, 0x6c, 0x65, 0x2e, 0x70, 0x72, 0x6f, 0x74, 0x6f, 0x62, 0x75,
	0x66, 0x2e, 0x54, 0x69, 0x6d, 0x65, 0x73, 0x74, 0x61, 0x6d, 0x70, 0x52, 0x04, 0x77, 0x68, 0x65,
	0x6e, 0x12, 0x2c, 0x0a, 0x03, 0x6e, 0x6f, 0x77, 0x18, 0x03, 0x20, 0x01, 0x28, 0x0b, 0x32, 0x1a,
	0x2e, 0x67, 0x6f, 0x6f, 0x67, 0x6c, 0x65, 0x2e, 0x70, 0x72, 0x6f, 0x74, 0x6f, 0x62, 0x75, 0x66,
	0x2e, 0x54, 0x69, 0x6d, 0x65, 0x73, 0x74, 0x61, 0x6d, 0x70, 0x52, 0x03, 0x6e, 0x6f, 0x77, 0x22,
	0x70, 0x0a, 0x07, 0x42, 0x61, 0x6c, 0x6c, 0x4f, 0x75, 0x74, 0x12, 0x14, 0x0a, 0x05, 0x72, 0x65,
	0x70, 0x6c, 0x79, 0x18, 0x01, 0x20, 0x01, 0x28, 0x09, 0x52, 0x05, 0x72, 0x65, 0x70, 0x6c, 0x79,
	0x12, 0x21, 0x0a, 0x0c, 0x74, 0x69, 0x6d, 0x65, 0x5f, 0x6d, 0x65, 0x73, 0x73, 0x61, 0x67, 0x65,
	0x18, 0x02, 0x20, 0x01, 0x28, 0x09, 0x52, 0x0b, 0x74, 0x69, 0x6d, 0x65, 0x4d, 0x65, 0x73, 0x73,
	0x61, 0x67, 0x65, 0x12, 0x2c, 0x0a, 0x03, 0x6e, 0x6f, 0x77, 0x18, 0x03, 0x20, 0x01, 0x28, 0x0b,
	0x32, 0x1a, 0x2e, 0x67, 0x6f, 0x6f, 0x67, 0x6c, 0x65, 0x2e, 0x70, 0x72, 0x6f, 0x74, 0x6f, 0x62,
	0x75, 0x66, 0x2e, 0x54, 0x69, 0x6d, 0x65, 0x73, 0x74, 0x61, 0x6d, 0x70, 0x52, 0x03, 0x6e, 0x6f,
	0x77, 0x22, 0x36, 0x0a, 0x04, 0x4c, 0x69, 0x6d, 0x62, 0x12, 0x14, 0x0a, 0x05, 0x63, 0x6f, 0x75,
	0x6e, 0x74, 0x18, 0x01, 0x20, 0x01, 0x28, 0x05, 0x52, 0x05, 0x63, 0x6f, 0x75, 0x6e, 0x74, 0x12,
	0x18, 0x0a, 0x07, 0x65, 0x6e, 0x64, 0x69, 0x6e, 0x67, 0x73, 0x18, 0x02, 0x20, 0x01, 0x28, 0x09,
	0x52, 0x07, 0x65, 0x6e, 0x64, 0x69, 0x6e, 0x67, 0x73, 0x22, 0x97, 0x01, 0x0a, 0x04, 0x42, 0x6f,
	0x64, 0x79, 0x12, 0x12, 0x0a, 0x04, 0x6e, 0x61, 0x6d, 0x65, 0x18, 0x01, 0x20, 0x01, 0x28, 0x09,
	0x52, 0x04, 0x6e, 0x61, 0x6d, 0x65, 0x12, 0x29, 0x0a, 0x05, 0x68, 0x61, 0x6e, 0x64, 0x73, 0x18,
	0x02, 0x20, 0x01, 0x28, 0x0b, 0x32, 0x13, 0x2e, 0x74, 0x61, 0x72, 0x67, 0x65, 0x74, 0x73, 0x65,
	0x72, 0x76, 0x69, 0x63, 0x65, 0x2e, 0x4c, 0x69, 0x6d, 0x62, 0x52, 0x05, 0x68, 0x61, 0x6e, 0x64,
	0x73, 0x12, 0x27, 0x0a, 0x04, 0x6c, 0x65, 0x67, 0x73, 0x18, 0x03, 0x20, 0x01, 0x28, 0x0b, 0x32,
	0x13, 0x2e, 0x74, 0x61, 0x72, 0x67, 0x65, 0x74, 0x73, 0x65, 0x72, 0x76, 0x69, 0x63, 0x65, 0x2e,
	0x4c, 0x69, 0x6d, 0x62, 0x52, 0x04, 0x6c, 0x65, 0x67, 0x73, 0x12, 0x27, 0x0a, 0x04, 0x74, 0x61,
	0x69, 0x6c, 0x18, 0x04, 0x20, 0x01, 0x28, 0x0b, 0x32, 0x13, 0x2e, 0x74, 0x61, 0x72, 0x67, 0x65,
	0x74, 0x73, 0x65, 0x72, 0x76, 0x69, 0x63, 0x65, 0x2e, 0x4c, 0x69, 0x6d, 0x62, 0x52, 0x04, 0x74,
	0x61, 0x69, 0x6c, 0x22, 0x3b, 0x0a, 0x07, 0x45, 0x63, 0x68, 0x6f, 0x4d, 0x73, 0x67, 0x12, 0x14,
	0x0a, 0x05, 0x61, 0x72, 0x72, 0x61, 0x79, 0x18, 0x01, 0x20, 0x03, 0x28, 0x09, 0x52, 0x05, 0x61,
	0x72, 0x72, 0x61, 0x79, 0x12, 0x1a, 0x0a, 0x08, 0x6e, 0x75, 0x6c, 0x6c, 0x61, 0x62, 0x6c, 0x65,
	0x18, 0x02, 0x20, 0x01, 0x28, 0x09, 0x52, 0x08, 0x6e, 0x75, 0x6c, 0x6c, 0x61, 0x62, 0x6c, 0x65,
	0x22, 0x84, 0x01, 0x0a, 0x07, 0x48, 0x65, 0x61, 0x64, 0x65, 0x72, 0x73, 0x12, 0x3d, 0x0a, 0x07,
	0x68, 0x65, 0x61, 0x64, 0x65, 0x72, 0x73, 0x18, 0x01, 0x20, 0x03, 0x28, 0x0b, 0x32, 0x23, 0x2e,
	0x74, 0x61, 0x72, 0x67, 0x65, 0x74, 0x73, 0x65, 0x72, 0x76, 0x69, 0x63, 0x65, 0x2e, 0x48, 0x65,
	0x61, 0x64, 0x65, 0x72, 0x73, 0x2e, 0x48, 0x65, 0x61, 0x64, 0x65, 0x72, 0x73, 0x45, 0x6e, 0x74,
	0x72, 0x79, 0x52, 0x07, 0x68, 0x65, 0x61, 0x64, 0x65, 0x72, 0x73, 0x1a, 0x3a, 0x0a, 0x0c, 0x48,
	0x65, 0x61, 0x64, 0x65, 0x72, 0x73, 0x45, 0x6e, 0x74, 0x72, 0x79, 0x12, 0x10, 0x0a, 0x03, 0x6b,
	0x65, 0x79, 0x18, 0x01, 0x20, 0x01, 0x28, 0x09, 0x52, 0x03, 0x6b, 0x65, 0x79, 0x12, 0x14, 0x0a,
	0x05, 0x76, 0x61, 0x6c, 0x75, 0x65, 0x18, 0x02, 0x20, 0x01, 0x28, 0x09, 0x52, 0x05, 0x76, 0x61,
	0x6c, 0x75, 0x65, 0x3a, 0x02, 0x38, 0x01, 0x22, 0x06, 0x0a, 0x04, 0x56, 0x6f, 0x69, 0x64, 0x32,
	0xd5, 0x04, 0x0a, 0x07, 0x42, 0x6f, 0x75, 0x6e, 0x63, 0x65, 0x72, 0x12, 0x9f, 0x01, 0x0a, 0x08,
	0x53, 0x61, 0x79, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x12, 0x1b, 0x2e, 0x74, 0x61, 0x72, 0x67, 0x65,
	0x74, 0x73, 0x65, 0x72, 0x76, 0x69, 0x63, 0x65, 0x2e, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x52, 0x65,
	0x71, 0x75, 0x65, 0x73, 0x74, 0x1a, 0x1c, 0x2e, 0x74, 0x61, 0x72, 0x67, 0x65, 0x74, 0x73, 0x65,
	0x72, 0x76, 0x69, 0x63, 0x65, 0x2e, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x52, 0x65, 0x73, 0x70, 0x6f,
	0x6e, 0x73, 0x65, 0x22, 0x58, 0x82, 0xd3, 0xe4, 0x93, 0x02, 0x52, 0x3a, 0x01, 0x2a, 0x5a, 0x34,
	0x5a, 0x0f, 0x22, 0x0d, 0x2f, 0x76, 0x31, 0x2f, 0x6d, 0x65, 0x73, 0x73, 0x61, 0x67, 0x65, 0x73,
	0x2f, 0x12, 0x21, 0x2f, 0x76, 0x31, 0x2f, 0x6d, 0x65, 0x73, 0x73, 0x61, 0x67, 0x65, 0x73, 0x2f,
	0x6c, 0x65, 0x67, 0x61, 0x63, 0x79, 0x2f, 0x7b, 0x67, 0x72, 0x65, 0x65, 0x74, 0x69, 0x6e, 0x67,
	0x3d, 0x2a, 0x2a, 0x7d, 0x12, 0x17, 0x2f, 0x76, 0x31, 0x2f, 0x6d, 0x65, 0x73, 0x73, 0x61, 0x67,
	0x65, 0x73, 0x2f, 0x7b, 0x67, 0x72, 0x65, 0x65, 0x74, 0x69, 0x6e, 0x67, 0x7d, 0x12, 0x6a, 0x0a,
	0x0d, 0x55, 0x6e, 0x6b, 0x6e, 0x6f, 0x77, 0x6e, 0x4d, 0x65, 0x74, 0x68, 0x6f, 0x64, 0x12, 0x1b,
	0x2e, 0x74, 0x61, 0x72, 0x67, 0x65, 0x74, 0x73, 0x65, 0x72, 0x76, 0x69, 0x63, 0x65, 0x2e, 0x48,
	0x65, 0x6c, 0x6c, 0x6f, 0x52, 0x65, 0x71, 0x75, 0x65, 0x73, 0x74, 0x1a, 0x1c, 0x2e, 0x74, 0x61,
	0x72, 0x67, 0x65, 0x74, 0x73, 0x65, 0x72, 0x76, 0x69, 0x63, 0x65, 0x2e, 0x48, 0x65, 0x6c, 0x6c,
	0x6f, 0x52, 0x65, 0x73, 0x70, 0x6f, 0x6e, 0x73, 0x65, 0x22, 0x1e, 0x82, 0xd3, 0xe4, 0x93, 0x02,
	0x18, 0x12, 0x16, 0x2f, 0x76, 0x31, 0x2f, 0x75, 0x6e, 0x6b, 0x6e, 0x6f, 0x77, 0x6e, 0x2f, 0x7b,
	0x67, 0x72, 0x65, 0x65, 0x74, 0x69, 0x6e, 0x67, 0x7d, 0x12, 0x4d, 0x0a, 0x08, 0x42, 0x6f, 0x75,
	0x6e, 0x63, 0x65, 0x49, 0x74, 0x12, 0x15, 0x2e, 0x74, 0x61, 0x72, 0x67, 0x65, 0x74, 0x73, 0x65,
	0x72, 0x76, 0x69, 0x63, 0x65, 0x2e, 0x42, 0x61, 0x6c, 0x6c, 0x49, 0x6e, 0x1a, 0x16, 0x2e, 0x74,
	0x61, 0x72, 0x67, 0x65, 0x74, 0x73, 0x65, 0x72, 0x76, 0x69, 0x63, 0x65, 0x2e, 0x42, 0x61, 0x6c,
	0x6c, 0x4f, 0x75, 0x74, 0x22, 0x12, 0x82, 0xd3, 0xe4, 0x93, 0x02, 0x0c, 0x3a, 0x01, 0x2a, 0x22,
	0x07, 0x2f, 0x62, 0x6f, 0x75, 0x6e, 0x63, 0x65, 0x12, 0x4b, 0x0a, 0x08, 0x47, 0x72, 0x6f, 0x77,
	0x54, 0x61, 0x69, 0x6c, 0x12, 0x13, 0x2e, 0x74, 0x61, 0x72, 0x67, 0x65, 0x74, 0x73, 0x65, 0x72,
	0x76, 0x69, 0x63, 0x65, 0x2e, 0x42, 0x6f, 0x64, 0x79, 0x1a, 0x13, 0x2e, 0x74, 0x61, 0x72, 0x67,
	0x65, 0x74, 0x73, 0x65, 0x72, 0x76, 0x69, 0x63, 0x65, 0x2e, 0x42, 0x6f, 0x64, 0x79, 0x22, 0x15,
	0x82, 0xd3, 0xe4, 0x93, 0x02, 0x0f, 0x12, 0x0d, 0x2f, 0x76, 0x31, 0x2f, 0x67, 0x72, 0x6f, 0x77,
	0x2f, 0x74, 0x61, 0x69, 0x6c, 0x12, 0x4b, 0x0a, 0x04, 0x45, 0x63, 0x68, 0x6f, 0x12, 0x16, 0x2e,
	0x74, 0x61, 0x72, 0x67, 0x65, 0x74, 0x73, 0x65, 0x72, 0x76, 0x69, 0x63, 0x65, 0x2e, 0x45, 0x63,
	0x68, 0x6f, 0x4d, 0x73, 0x67, 0x1a, 0x16, 0x2e, 0x74, 0x61, 0x72, 0x67, 0x65, 0x74, 0x73, 0x65,
	0x72, 0x76, 0x69, 0x63, 0x65, 0x2e, 0x45, 0x63, 0x68, 0x6f, 0x4d, 0x73, 0x67, 0x22, 0x13, 0x82,
	0xd3, 0xe4, 0x93, 0x02, 0x0d, 0x3a, 0x01, 0x2a, 0x22, 0x08, 0x2f, 0x76, 0x31, 0x2f, 0x65, 0x63,
	0x68, 0x6f, 0x12, 0x53, 0x0a, 0x0b, 0x45, 0x63, 0x68, 0x6f, 0x48, 0x65, 0x61, 0x64, 0x65, 0x72,
	0x73, 0x12, 0x13, 0x2e, 0x74, 0x61, 0x72, 0x67, 0x65, 0x74, 0x73, 0x65, 0x72, 0x76, 0x69, 0x63,
	0x65, 0x2e, 0x56, 0x6f, 0x69, 0x64, 0x1a, 0x16, 0x2e, 0x74, 0x61, 0x72, 0x67, 0x65, 0x74, 0x73,
	0x65, 0x72, 0x76, 0x69, 0x63, 0x65, 0x2e, 0x48, 0x65, 0x61, 0x64, 0x65, 0x72, 0x73, 0x22, 0x17,
	0x82, 0xd3, 0xe4, 0x93, 0x02, 0x11, 0x12, 0x0f, 0x2f, 0x76, 0x31, 0x2f, 0x65, 0x63, 0x68, 0x6f,
	0x68, 0x65, 0x61, 0x64, 0x65, 0x72, 0x73, 0x42, 0x11, 0x5a, 0x0f, 0x2e, 0x2f, 0x74, 0x61, 0x72,
	0x67, 0x65, 0x74, 0x73, 0x65, 0x72, 0x76, 0x69, 0x63, 0x65, 0x62, 0x06, 0x70, 0x72, 0x6f, 0x74,
	0x6f, 0x33,
}

var (
	file_targetservice_proto_rawDescOnce sync.Once
	file_targetservice_proto_rawDescData = file_targetservice_proto_rawDesc
)

func file_targetservice_proto_rawDescGZIP() []byte {
	file_targetservice_proto_rawDescOnce.Do(func() {
		file_targetservice_proto_rawDescData = protoimpl.X.CompressGZIP(file_targetservice_proto_rawDescData)
	})
	return file_targetservice_proto_rawDescData
}

var file_targetservice_proto_msgTypes = make([]protoimpl.MessageInfo, 10)
var file_targetservice_proto_goTypes = []any{
	(*HelloRequest)(nil),        // 0: targetservice.HelloRequest
	(*HelloResponse)(nil),       // 1: targetservice.HelloResponse
	(*BallIn)(nil),              // 2: targetservice.BallIn
	(*BallOut)(nil),             // 3: targetservice.BallOut
	(*Limb)(nil),                // 4: targetservice.Limb
	(*Body)(nil),                // 5: targetservice.Body
	(*EchoMsg)(nil),             // 6: targetservice.EchoMsg
	(*Headers)(nil),             // 7: targetservice.Headers
	(*Void)(nil),                // 8: targetservice.Void
	nil,                         // 9: targetservice.Headers.HeadersEntry
	(*timestamp.Timestamp)(nil), // 10: google.protobuf.Timestamp
}
var file_targetservice_proto_depIdxs = []int32{
	10, // 0: targetservice.BallIn.when:type_name -> google.protobuf.Timestamp
	10, // 1: targetservice.BallIn.now:type_name -> google.protobuf.Timestamp
	10, // 2: targetservice.BallOut.now:type_name -> google.protobuf.Timestamp
	4,  // 3: targetservice.Body.hands:type_name -> targetservice.Limb
	4,  // 4: targetservice.Body.legs:type_name -> targetservice.Limb
	4,  // 5: targetservice.Body.tail:type_name -> targetservice.Limb
	9,  // 6: targetservice.Headers.headers:type_name -> targetservice.Headers.HeadersEntry
	0,  // 7: targetservice.Bouncer.SayHello:input_type -> targetservice.HelloRequest
	0,  // 8: targetservice.Bouncer.UnknownMethod:input_type -> targetservice.HelloRequest
	2,  // 9: targetservice.Bouncer.BounceIt:input_type -> targetservice.BallIn
	5,  // 10: targetservice.Bouncer.GrowTail:input_type -> targetservice.Body
	6,  // 11: targetservice.Bouncer.Echo:input_type -> targetservice.EchoMsg
	8,  // 12: targetservice.Bouncer.EchoHeaders:input_type -> targetservice.Void
	1,  // 13: targetservice.Bouncer.SayHello:output_type -> targetservice.HelloResponse
	1,  // 14: targetservice.Bouncer.UnknownMethod:output_type -> targetservice.HelloResponse
	3,  // 15: targetservice.Bouncer.BounceIt:output_type -> targetservice.BallOut
	5,  // 16: targetservice.Bouncer.GrowTail:output_type -> targetservice.Body
	6,  // 17: targetservice.Bouncer.Echo:output_type -> targetservice.EchoMsg
	7,  // 18: targetservice.Bouncer.EchoHeaders:output_type -> targetservice.Headers
	13, // [13:19] is the sub-list for method output_type
	7,  // [7:13] is the sub-list for method input_type
	7,  // [7:7] is the sub-list for extension type_name
	7,  // [7:7] is the sub-list for extension extendee
	0,  // [0:7] is the sub-list for field type_name
}

func init() { file_targetservice_proto_init() }
func file_targetservice_proto_init() {
	if File_targetservice_proto != nil {
		return
	}
	type x struct{}
	out := protoimpl.TypeBuilder{
		File: protoimpl.DescBuilder{
			GoPackagePath: reflect.TypeOf(x{}).PkgPath(),
			RawDescriptor: file_targetservice_proto_rawDesc,
			NumEnums:      0,
			NumMessages:   10,
			NumExtensions: 0,
			NumServices:   1,
		},
		GoTypes:           file_targetservice_proto_goTypes,
		DependencyIndexes: file_targetservice_proto_depIdxs,
		MessageInfos:      file_targetservice_proto_msgTypes,
	}.Build()
	File_targetservice_proto = out.File
	file_targetservice_proto_rawDesc = nil
	file_targetservice_proto_goTypes = nil
	file_targetservice_proto_depIdxs = nil
}
