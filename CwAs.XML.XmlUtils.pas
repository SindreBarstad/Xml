
unit CwAs.Xml.XmlUtils;

interface

uses SysUtils,  Xml.XMLIntf;

type
  TXMLUtil = class(TObject)
  class var
    FFormat: TFormatSettings;
  private
  public
    class constructor Create;
    class function DateTimeToXML(aDateTime: TDateTime): string;
    class function DoubleToVar(const aValue: Double): Variant;
    class function FindChildNode(const aNode: IXMLNode; const aElementName: string; out aResultNode: IXMLNode): boolean;
    class function GetChildValue(const aNode: IXMLNode; const aElementName: string): variant;
    class function GetChildValueAsString(const aNode: IXMLNode; const aElementName: string): string;
    class function GetChildValueAsInteger(const aNode: IXMLNode; const aElementName: string): integer;
    class function GetChildValueAsDouble(const aNode: IXMLNode; const aElementName: string): double;
    class function GetChildValueAsBoolean(const aNode: IXMLNode; const aElementName: string): Boolean;
    class procedure StringToXml(var aString: string);
    class function VarToDouble(const aDoubleVar: variant): double; static;
    class function VarToInteger(const aIntVar: variant): Integer; static;
    class function XMLToDateTime(aStringDate: String): TDateTime;
    class procedure XmlToString(var aString: string); //Ikke i bruk. "Motsvarende" til StringToXml
  end;

implementation

uses
  Variants;

const
  XML_ACTUAL:       Array [0..4] of String = ('&','<','>', '"','''');
  XML_TRANSFORM:    Array [0..4] of String = ('&amp;','&lt;', '&gt;', '&quot;', '&apos;');

class constructor TXMLUtil.Create;
begin
  FFormat := TFormatSettings.Create;
  FFormat.DecimalSeparator := '.';
end;

class function TXMLUtil.DateTimeToXML(aDateTime: TDateTime): string;
begin
{
  Kan opgså gjøre det slik, men da legges tidsforskjell/tidssone til bakerst i strengen. Siden vi ikke vet helt hvordan
  vi skal takle dette, og vi ikke gidder å tenke på det akkurat nå, lar vi opprinnelig kode være som før.
  function DateTimeToXML(aDateTime: TDateTime): string;
  var
    vXSDateTime: TXSDateTime;
  begin
    vXSDateTime := TXSDateTime.Create;
    try
      vXSDateTime.AsDateTime := aDateTime;
      Result := vXSDateTime.NativeToXS;
    finally
      vXSDateTime.Free;
    end;
  end;
}
  if aDateTime = 0 then result := ''
  else
  begin
    Result := FormatDateTime('yyyy-mm-dd',aDateTime);
    if Frac(aDateTime) <> 0 then result := result + 'T' +
              FormatDateTime('hh":"nn":"ss',aDateTime);
  end;
end;

class function TXMLUtil.DoubleToVar(const aValue: Double): Variant;
begin
  Result := FloatToStr(aValue, FFormat);
end;

class function TXMLUtil.FindChildNode(const aNode: IXMLNode; const aElementName: string; out aResultNode: IXMLNode):
    boolean;
var
  I: Integer;
  vNode: IXMLNode;
begin
  aResultNode := nil;
  // Ikke casesensitive søk etter childe nodes
  for I := 0 to aNode.ChildNodes.Count - 1 do
  begin
    vNode := aNode.ChildNodes.Get(I);
    if (CompareText(vNode.LocalName,aElementName) = 0)
        or (CompareText(vNode.NodeName,aElementName) = 0)
    then
    begin
      aResultNode := vNode;
      exit(true);
    end;
  end;
  result := false;
end;

class function TXMLUtil.GetChildValue(const aNode: IXMLNode; const aElementName: string): variant;
var
  vNode: IXMLNode;
begin
  if FindChildNode(aNode,aElementName,vNode) then
    result := vNode.NodeValue
  else
    result := null;
end;

class function TXMLUtil.GetChildValueAsString(const aNode: IXMLNode; const aElementName: string): string;
begin
  result := VarToStr(GetChildValue(aNode, aElementName));
end;

class function TXMLUtil.GetChildValueAsInteger(const aNode: IXMLNode; const aElementName: string): integer;
begin
  result := VarToInteger(GetChildValue(aNode, aElementName));
end;

class function TXMLUtil.GetChildValueAsDouble(const aNode: IXMLNode; const aElementName: string): double;
begin
  result := VarToDouble(GetChildValue(aNode, aElementName));
end;

class function TXMLUtil.GetChildValueAsBoolean(const aNode: IXMLNode; const aElementName: string): Boolean;
begin
  result := VarToStr(GetChildValue(aNode, aElementName)) = 'true';
end;

class procedure TXMLUtil.StringToXml(var aString: string);
var
  I: Integer;
begin
  if not(aString = EmptyStr) then
     for I :=0 to High(XML_ACTUAL) do aString := StringReplace(aString, XML_ACTUAL[I], XML_TRANSFORM[I], [rfReplaceAll, rfIgnoreCase]);
end;

class function TXMLUtil.VarToDouble(const aDoubleVar: variant): double;
begin
  if VarIsNull(aDoubleVar) or VarIsEmpty(aDoubleVar) then
    Result := 0
  else
    result := StrToFloat(aDoubleVar,FFormat);
end;

class function TXMLUtil.VarToInteger(const aIntVar: variant): Integer;
begin
  if VarIsNull(aIntVar) or VarIsEmpty(aIntVar) then
    Result := 0
  else
    result := aIntVar;
end;

(*
function CheckValidDate(aDate: variant): Variant;
begin
  if VarType(aDate) <> varDate then Result := 0.0
  else Result := aDate;
end;
*)

class function TXMLUtil.XMLToDateTime(aStringDate: String): TDateTime;
begin
{
  Kan også gjøre det slik, emn kutter det ut pga problemstillinger rundt lagring av tidssone (se DateTimeToXML)

  function XMLToDateTime(aStringDate: String): TDateTime;
  var
    vXSDateTime: TXSDateTime;
  begin
    vXSDateTime := TXSDateTime.Create;
    try
      vXSDateTime.XSToNative(aStringDate);
      Result := vXSDateTime.AsDateTime;
    finally
      vXSDateTime.Free;
    end;
  end;
}
  if aStringDate = '' then result := 0
  else
  begin
    //try SB: Fjernet 04.03.2014
    Result := EncodeDate(StrToInt(Copy(aStringDate,1,4)), StrToInt(Copy(aStringDate,6,2)), StrToInt(Copy(aStringDate,9,2)) );
    if Copy(aStringDate,12,2) > '' then Result := Result + EncodeTime(StrToInt(Copy(aStringDate,12,2)), StrToInt(Copy(aStringDate,15,2)), StrToInt(Copy(aStringDate,18,2)), 0 );
    //except
    //end;
  end;
end;

class procedure TXMLUtil.XmlToString(var aString: string);
var
  I: Integer;
begin
  if not(aString = EmptyStr) and (Pos('&', aString) > 0) then
     for I :=0 to High(XML_ACTUAL) do aString := StringReplace(aString, XML_TRANSFORM[I], XML_ACTUAL[I], [rfReplaceAll, rfIgnoreCase]);
end;



end.
