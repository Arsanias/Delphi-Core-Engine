unit
  Core.Mail;

interface

uses
  System.Win.comObj, System.Variants, System.SysUtils,
  Winapi.Windows,
  Core.Types;

procedure SendMailOutlook( Subject: string; Recipients, Copies: PDynamicVariantArray; BodyText: string; Attachments, AttachmentNames: PDynamicVariantArray; SaveIt, OpenOutlook: Boolean);

implementation

/////////////////////////////////////////////////////////////////////////////////
/// https://docs.microsoft.com/de-de/office/vba/api/overview/outlook
///
procedure SendMailOutlook( Subject: string; Recipients, Copies: PDynamicVariantArray; BodyText: string; Attachments, AttachmentNames: PDynamicVariantArray; SaveIt, OpenOutlook: Boolean);
const
  olMailItem = $00000000;
  olByValue = $00000001;
  olTo = $00000001;
  olCC = $00000002;
  olBCC = $00000003;
var
  AOutlook: OleVariant;
  AMail: OleVariant;
  ARecipient: OleVariant;
  AAttachmentName: string;
  i: Integer;
begin
  { open outlook interface }

  AOutlook := CreateOleObject( 'Outlook.Application' );

  { create a new mail item }

  AMail := AOutlook.CreateItem( olMailItem );

  { add recipients }

  if( Length( Recipients^ ) > 0 ) then
    for i := 0 to Length( Recipients^ ) - 1 do
      AMail.Recipients.Add( Recipients^[ i ]);

  { add recipients in copy }

  if( Length( Copies^ ) > 0 ) then
    for i := 0 to Length( Copies^ ) - 1 do
    begin
      ARecipient := AMail.Recipients.Add( Copies^[ i ]);
      ARecipient.Type := olCC;
    end;

  { set subject and body text }

  AMail.Subject := Subject;
  AMail.Body    := BodyText;

  { add attachments }

  if Length(Attachments^) > 0 then
    for i := 0 to Length(Attachments^) - 1 do
    begin
      if ((Length(AttachmentNames^) > 0) and (AttachmentNames^[i] <> '')) then
        AAttachmentName := AttachmentNames^[i]
      else
        AAttachmentName := ExtractFileName(Attachments^[i]);
      AMail.Attachments.Add(Attachments^[i], olByValue, 1, AAttachmentName);
    end;

  { send mail }

  if OpenOutlook then
    //AOutlook.Show
    AMail.Display
  else
    AMail.Send;

  { clean Up }

  AMail       := Null;
  AOutlook    := Null;
end;

end.
