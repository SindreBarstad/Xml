unit CwAs.Xml.XmlSerializer.Attributes;

interface


type
  TCustomXmlAttribute = class(TCustomAttribute)
  end;

  XmlIgnoreAttribute = class(TCustomXmlAttribute)
  end;

  XmlElementAttribute = class(TCustomXmlAttribute)
  private
    FElementName: string;
  public
    constructor create(const name: string);
    property ElementName: string read FElementName write FElementName;
  end;

  XmlAttributeAttribute = class(TCustomXmlAttribute)
  private
    FAttributeName: string;
  public
    constructor create(const name: string);
    property AttributeName: string read FAttributeName write FAttributeName;
  end;

  XmlRootAttribute = class(TCustomXmlAttribute)
  private
    FElementName: string;
  public
    constructor create(const name: string);
    property ElementName: string read FElementName write FElementName;
  end;
    // For å eksluderer spesfikke properties på en klasse
  XmlExcludeMemberNamesAttribute = class(TCustomXmlAttribute)
  private
    FNames: string;
  public
    constructor create(const aNames: string);
    property Names: string read FNames write FNames;
  end;



implementation

{ XmlElementAttribute }

constructor XmlElementAttribute.create(const name: string);
begin
  FElementName := name;
end;

{ XmlAttributeAttribute }

constructor XmlAttributeAttribute.create(const name: string);
begin
  FAttributeName := name;
end;

{ XmlRootAttribute }

constructor XmlRootAttribute.create(const name: string);
begin
  FElementName := name;
end;

{ XmlExcludeMemberNamesAttribute }

constructor XmlExcludeMemberNamesAttribute.create(const aNames: string);
begin
  FNames := aNames;
end;

end.
