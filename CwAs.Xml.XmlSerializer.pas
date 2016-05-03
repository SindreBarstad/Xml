unit CwAs.Xml.XmlSerializer;
// MIT License
//
// Copyright (c) 2009 - Robert Love
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE
//
// ---------------------------------------------------------------------------
// XmlSerial - Written by Robert Love
// ---------------------------------------------------------------------------
//
// Actual HISTORY:
//
// Version 0.1
// -Basic support Classes and Record Properties
// -Attribute Syntax is now supported.
//
// Version 0.2 (on going with each commit!)
//   Changes to Help Support Lists, but not complete and really buggy right now
//   Changes Made to support Float and TDateTime,TTime and TDate in XML File
//   Version 0.2 TODO
//     -Finish Array and Enumeration Support
//     -Check and most likely add support for: Boolean, Decimal, BCD
//     -Add support for Stream - BinHex or Base 64 or something else need to look at .NET
// ---------------------------------------------------------------------------
// Roadmap:  (if you want to help, let me know!)
// ---------------------------------------------------------------------------
//
// Version 0.2
// -Array and Enumerations(LIsts) (Although it will attempt and most likely fail with class that contain these types.
//
// Version 0.3
// -DataTypes such as TDatetime need to match XML Types
// -Testing to see if this produces files compatable with .NET Xml Serialization
// HINT: Don't Depend on the structure produced until this is complete!
//
// Version 0.4
// -Better Error Handling, when unsupported types, etc... are found.
//
// Version 0.5 
// -Performance Tuning
//
// Version 1.0 - Then after some time, allowing for more testing to make it solid
//
// Some future version if someone finds a need for it, and wants to help.
// -Support XML namespaces???
// -Find or Write a XmlWriter and XmlReader clone for Win32 that would
// speed this up, and reduce the memory clue
//
//
// ---------------------------------------------------------------------------
// Programmers Notes:
// ---------------------------------------------------------------------------
// Although this is designed to have a similar interface to .NET XmlSerializer
// it is far from complete.   The goal in writing this code was two fold.
// 1. Example of how to use Attributes and the new RTTI in Delphi 2010
// 2. Allow classes that used these attributes to be cross compiled
// with Delphi Prism and have the same behavior.
// Specific Reason:
// I have a set of classes I need to be able use in both
// .NET (web service) and Win32 (Client)
// This unit does not need to cross compile, and TXmlSerializer is "T"
// since it does not have the same or simlar interface to XmlSerializer.
//
// Performance: This uses XmlDocument which means that the entire XML Document
// is read into RAM and then placed in your classes.
// I have not benchmarked anythign but I suspect during serialization
// you will need 2-3 times the amount of RAM that you classes
// will require.
//
// My application of this is really small so it not worth
// doing it another way.   But you have been warned!
//
//
// Usage Notes:
//
// Two ways to use:
//
//  The contructor of both classes, creates a MAP of RTTI Member to XML Element
//  The design is done to avoid having to query the RTTI information more than
//  needed. If you have to handle multiple Serialize or DeSerialize
//  calls during the scope of your application.   Performance wise it might
//  make semse to cache the serializer, and not recreate each time.
//
//
// Method 1:
//var
// o : TypeIWantToSerailze;
// s : TXmlTypeSerializer;
// x : TXmlDocument;
// v : TValue;
//begin
//  s := TXmlTypeSerializer.create(TypeInfo(o));
//  x := TXmlDocument.Create(Self); // NEVER PASS NIL!!!
//  s.Serialize(x,o);
//  x.SaveToFile('FileName.txt');
//  v := s.Deserialize(x);
//  o := v.AsType<TypeIWantToSerailze>;
//  x.free;
//  s.free;
//end;
// Method 2:
//var
// o : TypeIWantToSerailze;
// s : TXmlSerializer<TypeIWantToSerailze>;
// x : TXmlDocument;
//begin
//  s := TXmlTypeSerializer<TypeIWantToSerailze>.create;
//  x := TXmlDocument.Create(Self); // NEVER PASS NIL!!!
//  s.Serialize(x,o);
//  x.SaveToFile('FileName.txt');
// o := s.Deserialize(x);
//  x.free;
//  s.free;
//end;


interface

uses SysUtils, Classes, TypInfo, XmlDoc, XmlIntf, System.RTTI, Generics.Defaults,
  SyncObjs,  Generics.Collections, CwAs.Xml.XmlSerializer.Attributes;

const
  SAfterXMLDeserialize_MethodName = '_AfterXMLDeserialize';

type
  EXmlSerializationError = class(Exception);

  TCustomAttributeClass = class of TCustomAttribute;

  TMemberNodeType = (ntNone, ntElement, ntAttribute);

  TMemberNodeData = record
    NodeType: TMemberNodeType;
    NodeName: string;
  end;

  TMemberListType = (ltNone, ltEnum,ltArray);
  TMemberListTypeSet = set of TMemberListType;
const
  ValidMemberList : TMemberListTypeSet = [ltEnum,ltArray];

type
  TTypeNameMarshalling = class abstract(TObject)
  protected
  public
    function TypeName(aType : TRttiType) : String; virtual; abstract;
  end;

  TXmlDotNetNameMarshalling = class (TTypeNameMarshalling)
  private
  protected
    class var
      CS : TCriticalSection;
      Cache : TDictionary<string,string>;
    class constructor ClassCreate;
    class destructor ClassDestroy;
  public
    function TypeName(aType : TRttiType) : String; override;
  end;

  TMemberMap = record
  public
    Member: TRttiMember;
    NodeName: string;
    MemberDeclaredClassname: string;
    NodeType: TMemberNodeType;
    IsList : Boolean;
    ListItemName : String;
    ListMembers: TArray<TMemberMap>;
    ChildMembers: TArray<TMemberMap>;
    ExcludeNames: string;
    procedure Clear;
    class function ConstructMapForMember(var aCtx: TRttiContext; const aMember: TRttiMember; const aNameMarshaler:
        TTypeNameMarshalling): TMemberMap; static;
  end;

  TTypeMapping = class(TObject)
  public
    Map: TMemberMap;
    procedure Populate(var aContext: TRttiContext; aType: PTypeInfo;NameMarshaler : TTypeNameMarshalling); overload;
    procedure Populate(var aContext: TRttiContext; aRttiType: TRttiType;NameMarshaler : TTypeNameMarshalling);
      overload;
  end;


  TXmlCustomTypeSerializer = class abstract(TObject)
  private
    function FindTypeRTTI(const aClassName: string): TRttiType;
    procedure HandleAfterDeSerialize(const aValue: TValue);
  protected
    FMemberMap: TTypeMapping;
    FCtx: TRttiContext;
    FRootType: TRttiType;
    FNameMarshal : TTypeNameMarshalling;
  protected
    function CreateNameMarshaler : TTypeNameMarshalling; virtual;
    function CreateValue(aTypeInfo: PTypeInfo): TValue; virtual;
    procedure SerializeValue(const aValue: TValue; aMap: TMemberMap; aBaseNode: IXMLNode; aDoc: TXmlDocument); virtual;
//    function DeSerializeValue(aNode: IXMLNode; aMap: TMemberMap): TValue; overload; virtual;
    function DeSerializeValue(aNode: IXMLNode; aMapType: TRttiType; aMap: TMemberMap): TValue; overload; virtual;
    function ValueToString(const Value: TValue): string; virtual;
    function TextToValue(aType: TRttiType; const aText: string): TValue;

    procedure Serialize(var Doc: TXmlDocument; const ValueToSerialize: TValue);
      virtual;
    function Deserialize(Doc: TXmlDocument): TValue; virtual;
    constructor create(aType: PTypeInfo); virtual;

  public
    destructor Destroy; override;
  end;

  TXmlTypeSerializer = class(TXmlCustomTypeSerializer)
  public
    constructor create(aType: PTypeInfo); override;
    procedure Serialize(var Doc: TXmlDocument; const ValueToSerialize: TValue);
      override;
    function Deserialize(Doc: TXmlDocument): TValue; override;
  end;

  TXmlSerializer<T> = class(TXmlCustomTypeSerializer)
  public
    constructor create; reintroduce; virtual;
    procedure Serialize(var Doc: TXmlDocument; ValueToSerialize: T); reintroduce;
    function Deserialize(Doc: TXmlDocument): T; reintroduce;
  end;

  PObject = ^TObject;

implementation

uses
  XsBuiltins,
  CwAs.System.RttiUtils,
  System.Variants,
  System.StrUtils;



procedure TMemberMap.Clear;
begin
  NodeType := ntElement;
  Member := nil;
  NodeName := '';
  IsList := false;
  ChildMembers := nil;
  ListMembers := nil;
  MemberDeclaredClassname := '';
  ListItemName := '';
  ExcludeNames := '';
end;

{ TMemberMap }

class function TMemberMap.ConstructMapForMember(var aCtx: TRttiContext; const aMember: TRttiMember; const aNameMarshaler:
    TTypeNameMarshalling): TMemberMap;
var
  vAttr: TCustomAttribute;
  vDupe: Integer;
  vTypeMapping: TTypeMapping;
  vMemberType: TRttiType;
  vListMemberType: TRttiType;
  I: Integer;
  function _FindAttributes(aType: TRttiType; aAttributeClass: TCustomAttributeClass):TArray<TCustomAttribute>;
  //var
  //  vTmpList: TArray<TCustomAttribute>;
  //  vIndex: Integer;
  begin
    result := TAttrUtils.GetAttributes(aCtx,aType,aAttributeClass);
    // Det kan se ut til at koden nedenfor ikke er nødvendig og at GetAttributes vil finne attributter introdusert
    // tidligere i hiearakiet, men at det er en feil i Delphi sin håndtering av attributter på generiske typer.
    // Se: http://qc.embarcadero.com/wc/qcmain.aspx?d=82399
//    if Assigned(aType.BaseType) then
//    begin
//      vTmpList := _FindAttributes(aType.BaseType,aAttributeClass);
//      vIndex2 := Length(vTmpList);
//      if vIndex2 > 0 then
//      begin
//        SetLength(result,length(result)+ vIndex2);
//        for vIndex := Length(result) downto length(result) - vIndex2 do
//        begin
//          result[i] := vTmpList[vIndex2];
//          dec(vIndex2);
//        end;
//      end;
//    end;
  end;
begin
  // Default Values
  Result.Clear();
  Result.NodeType := ntElement;
  Result.Member := aMember;
  Result.NodeName := aMember.name;
  vDupe := 0;

  // Check Attributes for Custom overrides.
  for vAttr in aMember.GetAttributes do
  begin
    if vAttr is XmlIgnoreAttribute then
    begin
      Result.NodeType := ntNone;
      Result.NodeName := '';
    end
    else if vAttr is XmlElementAttribute then
    begin
      Result.NodeType := ntElement;
      Result.NodeName := XmlElementAttribute(vAttr).ElementName;
    end
    else if vAttr is XmlAttributeAttribute then
    begin
      Result.NodeType := ntAttribute;
      Result.NodeName := XmlAttributeAttribute(vAttr).AttributeName;
    end;
    if vAttr is TCustomXmlAttribute then
    begin
      inc(vDupe);
    end;
  end;

  // Finn attributter på klasser rekursivt
  if aMember.MemberType is TRttiStructuredType then
  begin
    for vAttr in _FindAttributes(aMember.MemberType, XmlExcludeMemberNamesAttribute) do
      if vAttr is XmlExcludeMemberNamesAttribute then
        Result.ExcludeNames := XmlExcludeMemberNamesAttribute(vAttr).Names;
  end;

  if vDupe > 1 then
    raise EXmlSerializationError.CreateFmt(
      'A member can have only one TCustomXmlAttribute: %s.%s',
      [aMember.Parent.QualifiedName, aMember.name]);


  if aMember is TRttiProperty then
    vMemberType := TRttiProperty(aMember).PropertyType
  else
    vMemberType := (aMember as TRttiField).FieldType;

  if not Assigned(vMemberType) then
  begin
    Result.NodeType := ntNone;
    exit;
  end;

  // Check for Special Type
  if (Result.NodeType <> ntNone) then
  begin
    if Assigned(aMember.MemberType) and TEnumerableFactory.IsTypeSupported(aMember.MemberType) and TElementAddFactory.TypeSupported(aMember.MemberType.Handle) then
    begin
      result.IsList := true;
      vListMemberType := aCtx.GetType(TElementAddFactory.GetAddType(aMember.MemberType.Handle));
      if Result.NodeType = ntAttribute then
      begin
        raise EXmlSerializationError.CreateFmt(
           'TXmlAttributeAttribute not supported for this member: %s.%s',
             [aMember.Parent.QualifiedName, aMember.name]);
      end;
      result.ListItemName := aNameMarshaler.TypeName(vListMemberType);
      result.MemberDeclaredClassname := result.ListItemName;
      vTypeMapping := TTypeMapping.create;
      try
        // Først sjekk finn alle members av list type
        vTypeMapping.Populate(aCtx, vListMemberType,aNameMarshaler);
        Result.ListMembers := Copy(vTypeMapping.Map.ChildMembers);
        // Så alle members til gjeldende type
        vTypeMapping.Populate(aCtx, vMemberType,aNameMarshaler);
        Result.ChildMembers := Copy(vTypeMapping.Map.ChildMembers);
      finally
        vTypeMapping.Free;
      end;
    end
    else
    begin
      if (aMember is TRttiProperty) and
        not (TRttiProperty(aMember).IsReadable
             and TRttiProperty(aMember).IsWritable) then
      begin
        // property must be readable and writable to be able to be streamed
        Result.NodeType := ntNone;
      end
      else
      begin
        if vMemberType.TypeKind in [tkRecord, tkClass] then
        begin
          result.MemberDeclaredClassname := vMemberType.Name;
          vTypeMapping := TTypeMapping.create;
          try
            vTypeMapping.Populate(aCtx, vMemberType,aNameMarshaler);
            Result.ChildMembers := Copy(vTypeMapping.Map.ChildMembers);
          finally
            vTypeMapping.Free;
          end;
        end;
      end;

    end;

    if Result.ExcludeNames > '' then
    begin
      for I := 0 to Length(result.ChildMembers)-1 do
        if ContainsText(Result.ExcludeNames,result.ChildMembers[i].NodeName) then
          result.ChildMembers[i].NodeType := ntNone;
    end;
  end;

end;

{ TMemberMapList }

procedure TTypeMapping.Populate(var aContext: TRttiContext; aType: PTypeInfo;NameMarshaler : TTypeNameMarshalling);
begin
  Populate(aContext, aContext.GetType(aType),NameMarshaler);
end;

procedure TTypeMapping.Populate(var aContext: TRttiContext;
  aRttiType: TRttiType;NameMarshaler : TTypeNameMarshalling);
var
  vMember: TRttiMember;
  vProperties: TArray<TRttiProperty>;
  vFields: TArray<TRttiField>;
  vCount: Integer;
  vRootAttr: TCustomAttribute;

  procedure _HandleMember(const aMember: TRTTIMember);
  var
    vMemberMap: TMemberMap;
  begin
    if aMember.Visibility in [mvPublic, mvPublished] then
    begin
      vMemberMap := TMemberMap.ConstructMapForMember(aContext, aMember,NameMarshaler);

      if Map.IsList and (vMemberMap.NodeType <> ntNone) and not vMemberMap.IsList then vMemberMap.NodeType := ntAttribute;

      if Map.IsList and vMemberMap.IsList then vMemberMap.NodeType := ntNone;

      if (vMemberMap.NodeType <> ntNone) then
      begin
        Map.ChildMembers[vCount] := vMemberMap;
        inc(vCount);
      end;
    end;
  end;
begin
  // Clear Old Contents and set Default Values
  Map.Clear();
  Map.NodeType := ntElement;

  if TAttrUtils.HasAttribute(aContext, aRttiType, XmlRootAttribute, vRootAttr) then
    Map.NodeName := (vRootAttr as XmlRootAttribute).ElementName
  else
    Map.NodeName := NameMarshaler.TypeName(aRttiType);

  Map.IsList := TEnumerableFactory.IsTypeSupported(aRttiType) and TElementAddFactory.TypeSupported(aRttiType.Handle);

  // Cache lists to avoid having to make Call Twice
  vProperties := aRttiType.GetProperties;
  vFields := aRttiType.GetFields;
  // Set to Max Possible Length
  SetLength(Map.ChildMembers, Length(vProperties) + Length(vFields));
  vCount := 0;
  for vMember in vFields do _HandleMember(vMember);
  for vMember in vProperties do _HandleMember(vMember);

  // Set Length back to size calculated
  SetLength(Map.ChildMembers, vCount);
// end;
end;


{ TXmlCustomTypeSerializer }

constructor TXmlCustomTypeSerializer.create(aType: PTypeInfo);
begin
  FNameMarshal := CreateNameMarshaler;
  FMemberMap := TTypeMapping.create;
  FCtx := TRttiContext.create;
  FMemberMap.Populate(FCtx, aType,FNameMarshal);
  FRootType := FCtx.GetType(aType);
end;

function TXmlCustomTypeSerializer.CreateNameMarshaler: TTypeNameMarshalling;
begin
  result := TXmlDotNetNameMarshalling.Create;
end;

function TXmlCustomTypeSerializer.CreateValue(aTypeInfo: PTypeInfo): TValue;
var
  rtType: TRttiStructuredType;
begin
  Result := nil;
  rtType := (FCtx.GetType(aTypeInfo) as TRttiStructuredType);
  if rtType is TRttiRecordType then
  begin
    TValue.Make(nil, aTypeInfo, Result);
  end
  else if rtType is TRttiInstanceType then
  begin
    // TODO: Support for Event to allow creation of classes with parameters on contrcutors
    // Not going to do this right now, not required
    Result := TRttiInstanceType(rtType).MetaclassType.create;
  end
  else
    raise EXmlSerializationError.CreateFmt
      ('Unsupported type %@', [rtType.QualifiedName]);

end;

function TXmlCustomTypeSerializer.Deserialize(Doc: TXmlDocument): TValue;
begin
  if not Doc.Active then
    Doc.Active := true;
  if Doc.IsEmptyDoc then
    raise EXmlSerializationError.create(
      'Nothing to  deserialize the document is empty.');

  Result := DeSerializeValue(Doc.Node.ChildNodes.First, FRootType, FMemberMap.Map);

end;

function TXmlCustomTypeSerializer.DeSerializeValue(aNode: IXMLNode; aMapType: TRttiType; aMap: TMemberMap): TValue;
var
  vChildNodeList: IXMLNodeList;
  vChildNode: IXMLNode;
  vMapItem: TMemberMap;
  vChildValue: TValue;
  I : Integer;
  vListValue : TValue;
  vElementAdd : TElementAdd;
  vEnumeratedMap : TMemberMap;
  vNodeClassName: string;
  vTmpMap: TTypeMapping;
  vRttiInstance: TRttiInstanceType;
  vValue: TValue;
  vConstructors: TArray<TRttiMethod>;
  vConstructor, vConstructorIterator: TRttiMethod;
begin
 if aMapType.IsInstance then
 begin
    vNodeClassName := VarToStr(aNode.Attributes['Classname']);
    if (vNodeClassName > '') and (vNodeClassName <> aMapType.AsInstance.Name) then
    begin
      aMapType := FindTypeRTTI(vNodeClassName);

      vTmpMap := TTypeMapping.create;
      try
        vTmpMap.Populate(FCtx, aMapType, FNameMarshal);
        aMap.ChildMembers := vTmpMap.Map.ChildMembers;
      finally
        vTmpMap.Free;
      end;
    end;
    // 10.02.2012 SB: Adjusted to handle calling virtual constructors (only on parameterless constructors)
    vRttiInstance := aMapType.AsInstance;
    vConstructor := nil;
    vConstructors := vRttiInstance.GetMethods('create');
    for vConstructorIterator in vConstructors do
      if Length(vConstructorIterator.GetParameters) = 0 then
      begin
        vConstructor := vConstructorIterator;
        break;
      end;

    if Assigned(vConstructor) then  // Parameter less constructor
    begin
      vValue :=  vConstructor.Invoke(vRttiInstance.MetaclassType,[]);
      result := vValue.AsObject;
    end
    else Result := aMapType.AsInstance.MetaclassType.create;
 end
 else
 begin
    // Create an Empty Record, Value Type, etc....
    TValue.Make(nil, aMapType.Handle, Result);
 end;
 // structure type with Mapped Members, and it's not a list type
 if (aMapType is TRttiStructuredType) and (Length(aMap.ChildMembers) > 0) and (Not aMap.IsList) then
 begin
    vChildNodeList := aNode.ChildNodes;
    for vMapItem in aMap.ChildMembers do
    begin
      case vMapItem.NodeType of
        ntElement:   begin
                       vChildNode := vChildNodeList.FindNode(vMapItem.NodeName);
                       if not Assigned(vChildNode) then // SB: Hvis den ikke finnes som element, prøv med attribute
                         vChildNode := aNode.AttributeNodes.FindNode(vMapItem.NodeName)
                     end;
        ntAttribute: begin
                       if aNode.HasAttribute(vMapItem.NodeName) then
                         vChildNode := aNode.AttributeNodes.FindNode(vMapItem.NodeName)
                       else
                       begin // SB: 29.11.12: Hvis den ikke finnes som Attribute, prøv som element. Dette muligjør endring fra ElementType til Attribute type
                         vChildNode := vChildNodeList.FindNode(vMapItem.NodeName);
                       end;
                      end;
      end; { Case }
      if Assigned(vChildNode) then
      begin
        vChildValue := DeSerializeValue(vChildNode, vMapItem.Member.MemberType, vMapItem);
        if not vChildValue.isEmpty then
          vMapItem.Member.SetValue(Result, vChildValue);
      end;
    end;
 end
 else if aMap.IsList then
 begin
     vChildNodeList := aNode.ChildNodes;
    // Create Correct Element Add Factory
    vElementAdd := TElementAddFactory.CreateElementAdd(Result);
    // Loop through items to add.
    for I := 0 to vChildNodeList.Count - 1 do
    begin
      vChildNode := vChildNodeList.Nodes[I];
      vEnumeratedMap := aMap;
      vEnumeratedMap.IsList := false;
      vEnumeratedMap.NodeType := ntElement;
      vEnumeratedMap.ChildMembers := Copy(aMap.ListMembers);

      vListValue := DeSerializeValue(vChildNode,FCtx.GetType(vElementAdd.AddType),vEnumeratedMap);
      vElementAdd.Add(vListValue);
    end;
    vElementAdd.AddFinalize;
    result := vElementAdd.List;
    FreeAndNil(vElementAdd);
 end
 else // Not a structure Type or List, convert from String to Value
 begin
    if aNode.Text > '' then
      Result := TextToValue(aMapType, aNode.Text);
  end;

 // SB: Check if the created instance has the _AfterXMLDeserializeMethod
 if not result.IsEmpty and result.IsObject then HandleAfterDeSerialize(result);
end;

//function TXmlCustomTypeSerializer.DeSerializeValue
//  (Node: IXMLNode; Map: TMemberMap): TValue;
//var
//  Children: IXMLNodeList;
//  Child: IXMLNode;
//  MapItem: TMemberMap;
//  ListMapItem : TMemberMap;
//  ChildValue: TValue;
//  ResultType: TRttiType;
//  I : Integer;
//  ListValue : TValue;
//  lAdd : TElementAdd;
//
//begin
//// Riddled with duplicated code, need to rethink and refactor
//  if Map.isList then
//  begin
//    Children := Node.ChildNodes;
//    if Assigned(Map.Member) then
//        ResultType := Map.Member.MemberType
//    else
//        ResultType := FRootType;
//
//    // Create Result TValue
//    if ResultType.IsInstance then
//    begin
//      Result := ResultType.AsInstance.MetaclassType.create;
//    end
//    else
//    begin
//      TValue.Make(nil, ResultType.Handle, Result);
//    end;
//
//    // Create Correct Element Add Factory
//    lAdd := TElementAddFactory.CreateElementAdd(Result);
//    // Loop through items to add.
//    for I := 0 to Children.Count - 1 do
//    begin
//      Child := Children.Nodes[I];
//      TextToValue(ResultType,Child.Text);
//      ListValue := DeserializeValue(Node,Map);
//      lAdd.Add(ListValue);
//    end;
//    lAdd.AddFinalize;
//  end
//  else
//  begin
//
//      begin
//        if  (Length(Map.List) > 0) then // Must be Structured Type
//        begin
//          if Assigned(Map.Member) then
//            ResultType := Map.Member.MemberType
//          else
//            ResultType := FRootType;
//
//          if not(ResultType is TRttiStructuredType) then
//            raise EXmlSerializationError.create(
//              'Expecting a structured type to Deserialize');
//          // Create Result TValue
//          if ResultType.IsInstance then
//          begin
//            Result := ResultType.AsInstance.MetaclassType.create;
//          end
//          else
//          begin
//            TValue.Make(nil, ResultType.Handle, Result);
//          end;
//
//          Children := Node.ChildNodes;
//          for MapItem in Map.List do
//          begin
//            case MapItem.NodeType of
//              ntElement: Child := Children.FindNode(MapItem.NodeName);
//              ntAttribute: begin
//                             if Node.HasAttribute(MapItem.NodeName) then
//                               Child := Node.AttributeNodes.FindNode(MapItem.NodeName)
//                             else
//                               Child :=nil;
//                            end;
//            end; { Case }
//            if Assigned(Child) then
//            begin
//              ChildValue := DeSerializeValue(Child, MapItem);
//              if not ChildValue.isEmpty then
//                MapItem.Member.SetValue(Result, ChildValue);
//            end;
//          end;
//
//        end
//        else
//        begin // Not a structure Type, convert from String to Value
//          if Assigned(Map.Member) then
//            ResultType := Map.Member.MemberType
//          else
//            ResultType := FRootType;
//          Result := TextToValue(ResultType, Node.Text);
//        end;
//      end;
//  end;
//end;

destructor TXmlCustomTypeSerializer.Destroy;
begin
  FMemberMap.Free;
  FNameMarshal.Free;
  inherited;
end;

function TXmlCustomTypeSerializer.FindTypeRTTI(const aClassName: string): TRttiType;
var
  vType: TRTTIType;
begin
  result := nil;
  for vType in Fctx.GetTypes do
    if (vType.Name = aClassName) then exit(vType);
end;

procedure TXmlCustomTypeSerializer.HandleAfterDeSerialize(const aValue: TValue);
var
  vRttiInstance: TRttiInstanceType;
  vMethod: TRttiMethod;
begin
  // Check if the instance has a method named _AfterXMLDeserialize and eventuall call it
  vRttiInstance := TRttiInstanceType(FCtx.GetType(aValue.TypeInfo));
  vMethod := vRttiInstance.GetMethod(SAfterXMLDeserialize_MethodName);
  if Assigned(vMethod) and (Length(vMethod.GetParameters) = 0) then
   vMethod.Invoke(aValue.AsObject,[]);
end;

procedure TXmlCustomTypeSerializer.Serialize(var Doc: TXmlDocument;
  const ValueToSerialize: TValue);
begin
  if not Doc.IsEmptyDoc then
    raise EXmlSerializationError.create(
      'Document must be empty to serialize to it.');
  if not Doc.Active then
    Doc.Active := true;

  SerializeValue(ValueToSerialize, FMemberMap.Map, nil, Doc);
end;

procedure TXmlCustomTypeSerializer.SerializeValue(const aValue: TValue; aMap: TMemberMap; aBaseNode: IXMLNode; aDoc:
    TXmlDocument);
var
  vNewNode: IXMLNode;
  vEnumeratedMap: TMemberMap;
  vCurrentValue: TValue;
  vMapItem: TMemberMap;
  vEnumFactory :  TEnumerableFactory;
  vEnumerator : TEnumerator<TValue>;
  vTmpMap: TTypeMapping;
begin
  if aValue.IsEmpty or (aValue.Kind = tkUnknown) then exit;

  case aMap.NodeType of
    ntNone:
      exit; // Do Nothing, but then really should have not been the list to begin with!
    ntElement:
      begin
        if not Assigned(aBaseNode) then
          vNewNode := aDoc.AddChild(aMap.NodeName)
        else
          vNewNode := aBaseNode.AddChild(aMap.NodeName);

        if (aValue.TypeInfo.Kind = tkClass) and (aMap.MemberDeclaredClassname > '') and (aMap.MemberDeclaredClassname <> aValue.TypeInfo.Name) and not aMap.IsList then
        begin
          // Hvis runtime klassen er av annen type (nedarvet) en deklarert, så må member aMap kjøres på nytt
          vNewNode.Attributes['Classname'] := aValue.TypeInfo.Name;
          vTmpMap := TTypeMapping.create;
          try
            vTmpMap.Populate(FCtx, aValue.TypeInfo, FNameMarshal);
            aMap.ChildMembers := vTmpMap.Map.ChildMembers;
          finally
            vTmpMap.Free;
          end;
        end;
        // if Record or Object
        if Length(aMap.ChildMembers) > 0 then
        begin
          //if Not (aMap.IsList) then
          //begin
            for vMapItem in aMap.ChildMembers do
            begin
              Assert(Assigned(vMapItem.Member));
              vCurrentValue := vMapItem.Member.GetValue(aValue);
              SerializeValue(vCurrentValue, vMapItem, vNewNode, aDoc);
            end;
          //end;
        end
        else
        begin
          if Not (aMap.IsList) then
            vNewNode.Text := ValueToString(aValue);
        end;
      end;
    ntAttribute:
      begin
        // This should have already been done, so just assert instead of exception.
        Assert(not aMap.IsList, 'XmlAtttribute applied to an List Type');
        Assert(Length(aMap.ChildMembers) = 0,
          'XmlAtttribute applied to a aMap.List that is not Zero.');
        aBaseNode.Attributes[aMap.NodeName] := ValueToString(aValue);
      end;
  end;

  if aMap.IsList then
  begin
    vEnumeratedMap := aMap;
    vEnumeratedMap.NodeName := aMap.ListItemName;
    vEnumeratedMap.IsList := false;
    vEnumeratedMap.ChildMembers := Copy(aMap.ListMembers);

    vEnumFactory := TEnumerableFactory.Create(aValue);
    vEnumerator := vEnumFactory.GetEnumerator;
    try
      while vEnumerator.MoveNext do
      begin
        vCurrentValue := vEnumerator.Current;
  //      EnumNode := NewNode.AddChild(TElementAddFactory.GetAddType(aValue.TypeInfo).Name , '');
        SerializeValue(vCurrentValue, vEnumeratedMap, vNewNode, aDoc);
      end;
    finally
      FreeAndNil(vEnumerator);
      FreeAndNil(vEnumFactory);
    end;
  end;
end;

function TXmlCustomTypeSerializer.TextToValue
  (aType: TRttiType; const aText: string): TValue;
var
  I: Integer;
  xsDate : TXSDate;
  xsTime : TXSTime;
  xsDateTime : TXSDateTime;
begin
  case aType.TypeKind of
    tkWChar, tkLString, tkWString, tkString, tkChar, tkUString:
      Result := aText;
    tkInteger, tkInt64:
      Result := StrToInt(aText);
    tkFloat:
    begin
      if aType.Name = 'TDate' then
      begin
        xsDate := TXSDate.Create;
        try
        xsDate.XSToNative(aText);
        result := xsDate.AsDate;
        finally
           xsDate.Free;
        end;
      end
      else if aType.Name = 'TTime' then
      begin
        xsTime := TXSTime.Create;
        try
        xsTime.XSToNative(aText);
        result := xsTime.AsTime;
        finally
           xsTime.Free;
        end;

      end
      else if aType.Name = 'TDateTime' then
      begin
        xsDateTime := TXSDateTime.Create;
        try
        xsDateTime.XSToNative(aText);
        result := xsDateTime.AsDateTime;
        finally
           xsDateTime.Free;
        end;
      end
      else   Result :=  SoapStrToFloat(aText);

    end;
    tkEnumeration:
      Result := TValue.FromOrdinal
        (aType.Handle, GetEnumValue(aType.Handle, aText));
    tkSet:
      begin
        I := StringToSet(aType.Handle, aText);
        TValue.Make(@I, aType.Handle, Result);
      end;
    tkVariant:
      begin
        result := TValue.FromVariant(aText);
      end;
  else
    raise EXmlSerializationError.create('Type not Supported, yet...');
  end;

end;

function TXmlCustomTypeSerializer.ValueToString(const Value: TValue): string;
var
  xsDate : TXSDate;
  xsTime : TXSTime;
  xsDateTime : TXSDateTime;
begin

  case Value.Kind of
    tkClass: result := '';
    tkWChar, tkLString, tkWString, tkString, tkChar, tkUString:
      Result := Value.ToString;
    tkInteger, tkInt64:
      Result := Value.ToString;
    tkFloat:
    begin
      if Value.TypeInfo.Name = 'TDate' then
      begin
        xsDate := TXSDate.Create;
        try
        xsDate.AsDate := Value.AsExtended;
        result :=  xsDate.NativeToXS;
        finally
           xsDate.Free;
        end;
      end
      else if Value.TypeInfo.Name = 'TTime' then
      begin
        xsTime := TXSTime.Create;
        try
        xsTime.AsTime := Value.AsExtended;
        result :=  xsTime.NativeToXS;
        finally
           xsTime.Free;
        end;
      end
      else if Value.TypeInfo.Name = 'TDateTime' then
      begin
        xsDateTime := TXSDateTime.Create;
        try
          xsDateTime.AsDateTime := Value.AsExtended;
          result :=  xsDateTime.NativeToXS;
        finally
           xsDateTime.Free;
        end;
      end
      else
         Result :=  SoapFloatToStr(Value.AsExtended);
    end;
    tkEnumeration:
      Result := Value.ToString;
    tkSet:
      Result := Value.ToString;
    tkVariant:
      begin
        result := VarToStr(Value.AsVariant);
      end;
  else
    raise EXmlSerializationError.create('Type not Supported, yet...');
  end;
end;

{ TXmlTypeSerializer }

constructor TXmlTypeSerializer.create(aType: PTypeInfo);
begin
  inherited create(aType);
end;

function TXmlTypeSerializer.Deserialize(Doc: TXmlDocument): TValue;
begin
  Result := inherited Deserialize(Doc);
end;

procedure TXmlTypeSerializer.Serialize(var Doc: TXmlDocument;
  const ValueToSerialize: TValue);
begin
  inherited Serialize(Doc, ValueToSerialize);

end;

{ TXmlSerializer<T> }

constructor TXmlSerializer<T>.create;
begin
  inherited create(TypeInfo(T));
end;

function TXmlSerializer<T>.Deserialize(Doc: TXmlDocument): T;
var
  V: TValue;
begin
  V := inherited Deserialize(Doc);
  Result := V.AsType<T>;
end;

procedure TXmlSerializer<T>.Serialize(var Doc: TXmlDocument;
  ValueToSerialize: T);
var
  V: TValue;
begin
  V := TValue.From<T>(ValueToSerialize);
  inherited Serialize(Doc, V);
end;


{ TXmlDotNetNameMarshalling }

class constructor TXmlDotNetNameMarshalling.ClassCreate;
begin
  Cache := TDictionary<string,string>.Create;
  // Standard Types and how .NET returns them,
  // it would not be my choice for type names
  // a name like unsignedByte for a single byte seems insane.
  Cache.Add('system.byte','unsignedByte'); // do not localize
  Cache.Add('system.shortint','byte'); // do not localize
  Cache.Add('system.smallint','short'); // do not localize
  Cache.Add('system.longint','int'); // do not localize
  Cache.Add('system.integer','int'); // do not localize
  Cache.Add('system.int64','long'); // do not localize
  Cache.Add('system.word','short'); // do not localize
  Cache.Add('system.longword','int'); // do not localize
  Cache.Add('system.cardinal','int'); // do not localize
  Cache.Add('system.uint64','long'); // do not localize
  Cache.Add('system.boolean','boolean'); // do not localize
  Cache.Add('system.double','double'); // do not localize
  Cache.Add('system.extended','double'); // do not localize
  Cache.Add('system.comp','double'); // do not localize
  Cache.Add('system.currency','double'); // do not localize
  Cache.Add('system.single','float'); // do not localize
  Cache.Add('system.tdate','dateTime'); // do not localize
  Cache.Add('system.tdatetime','dateTime'); // do not localize
  Cache.Add('system.time','dateTime'); // do not localize
  CS := TCriticalSection.Create;
end;

class destructor TXmlDotNetNameMarshalling.ClassDestroy;
begin
  Cache.Free;
  CS.Free;
end;

function TXmlDotNetNameMarshalling.TypeName(aType: TRttiType): String;
var
 token : String;
 Idx : Integer;
 tokenStart : Integer;
 lowertype : String;
 typelen : Integer;

begin
  CS.Acquire;
  try
    lowertype := lowercase(aType.Name);
    if not Cache.TryGetValue(lowertype,result) then
    begin
      //TODO: Implement Enumerations such as TList<Integer> = ArrayOfInt

      idx := Pos(lowertype,'<');
      if idx > 0 then  // Check to see if Generic Type
      begin
        result := Copy(aType.Name,1,idx) + 'Of'; // do not localize
        typelen := Length(lowertype);
        tokenStart := idx + 1;
        while idx < typelen do
        begin
          inc(idx);
          if CharInSet(lowertype[idx],[',','>']) then
          begin
            token := copy(lowertype,tokenstart,tokenstart-idx); // Mixed case name on purpose
            if Not Cache.TryGetValue(token,token) then // Replace token with what is in cache as the case and name may change
            begin
              // pTypeInfo.Name does not include Unit Name
               Cache.Add(token, aType.Handle.Name);
               Token := aType.Handle.Name;
            end;
            result := result + token;
            tokenStart := idx + 1;
          end;
          if lowerType[idx]= '<' then
          begin
             result := result + Copy(aType.Name,tokenstart,tokenstart-idx) + 'Of'; // do not localize
             tokenStart := idx + 1;
          end;
        end;
      end
      else result := aType.Handle.Name;


      Cache.Add(lowertype,result);
    end;
  finally
    CS.Release;
  end;
end;



end.
