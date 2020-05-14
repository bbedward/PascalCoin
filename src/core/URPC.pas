unit URPC;

{ Copyright (c) 2016 by Albert Molina

  Distributed under the MIT software license, see the accompanying file LICENSE
  or visit http://www.opensource.org/licenses/mit-license.php.

  This unit is a part of the PascalCoin Project, an infinitely scalable
  cryptocurrency. Find us here:
  Web: https://www.pascalcoin.org
  Source: https://github.com/PascalCoin/PascalCoin

  If you like it, consider a donation using Bitcoin:
  16K3HCZRhFUtM8GdWRcfKeaa6KsuyxZaYk

  THIS LICENSE HEADER MUST NOT BE REMOVED.
}

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

interface

{$I ./../config.inc}

Uses UThread, ULog, UConst, UNode, UAccounts, UCrypto, UBlockChain,
  UNetProtocol, UOpTransaction, UWallet, UTime, UPCEncryption, UTxMultiOperation,
  UJSONFunctions, classes, blcksock, synsock,
  IniFiles, Variants, math, UBaseTypes,
  {$IFDEF Use_OpenSSL}
  UOpenSSL,
  {$ENDIF}
  UPCOrderedLists, UPCDataTypes,
  {$IFNDEF FPC}System.Generics.Collections{$ELSE}Generics.Collections{$ENDIF},
  UNetProtection;

Const
  CT_RPC_ErrNum_InternalError = 100;
  CT_RPC_ErrNum_NotImplemented = 101;

  CT_RPC_ErrNum_MethodNotFound = 1001;
  CT_RPC_ErrNum_InvalidAccount = 1002;
  CT_RPC_ErrNum_InvalidBlock = 1003;
  CT_RPC_ErrNum_InvalidOperation = 1004;
  CT_RPC_ErrNum_InvalidPubKey = 1005;
  CT_RPC_ErrNum_InvalidAccountName = 1006;
  CT_RPC_ErrNum_NotFound = 1010;
  CT_RPC_ErrNum_WalletPasswordProtected = 1015;
  CT_RPC_ErrNum_InvalidData = 1016;
  CT_RPC_ErrNum_InvalidSignature = 1020;
  CT_RPC_ErrNum_NotAllowedCall = 1021;

Type

  { TRPCServer }

  { TPascalCoinJSONComp }

  TPascalCoinJSONComp = Class
  private
    class function OperationsHashTreeToHexaString(Const OperationsHashTree : TOperationsHashTree) : String;
  public
    class procedure FillAccountObject(Const account : TAccount; jsonObj : TPCJSONObject);
    class procedure FillBlockObject(nBlock : Cardinal; ANode : TNode; jsonObject: TPCJSONObject);
    class procedure FillOperationObject(Const OPR : TOperationResume; currentNodeBlocksCount : Cardinal; jsonObject : TPCJSONObject);
    class procedure FillOperationsHashTreeObject(Const OperationsHashTree : TOperationsHashTree; jsonObject : TPCJSONObject);
    class procedure FillMultiOperationObject(current_protocol : Word; Const multiOperation : TOpMultiOperation; jsonObject : TPCJSONObject);
    class procedure FillPublicKeyObject(const PubKey : TAccountKey; jsonObj : TPCJSONObject);
    class function ToPascalCoins(jsonCurr : Real) : Int64;
    //
    class Function HexaStringToOperationsHashTree(Const AHexaStringOperationsHashTree : String; ACurrentProtocol : Word; out AOperationsHashTree : TOperationsHashTree; var AErrors : String) : Boolean;
    class Function CapturePubKey(const AInputParams : TPCJSONObject; const APrefix : String; var APubKey : TAccountKey; var AErrortxt : String) : Boolean;
    class function CheckAndGetEncodedRAWPayload(Const ARawPayload : TRawBytes; Const APayload_method, AEncodePwdForAES : String; const ASenderAccounKey, ATargetAccountKey : TAccountKey; out AOperationPayload : TOperationPayload; Var AErrorNum : Integer; Var AErrorDesc : String) : Boolean;
  end;

  TRPCServerThread = Class;
  TRPCServer = Class
  private
    FRPCServerThread : TRPCServerThread;
    FActive: Boolean;
    FWalletKeys: TWalletKeysExt;
    FPort: Word;
    FJSON20Strict: Boolean;
    FIniFileName: String;
    FIniFile : TIniFile;
    FRPCLog : TLog;
    FCallsCounter : Int64;
    FValidIPs: String;
    FAllowUsePrivateKeys: Boolean;
    FNode : TNode;
    procedure SetActive(AValue: Boolean);
    procedure SetIniFileName(const Value: String);
    procedure SetLogFileName(const Value: String);
    Function GetLogFileName : String;
    procedure SetValidIPs(const Value: String);  protected
    Function IsValidClientIP(Const clientIp : String; clientPort : Word) : Boolean;
    Procedure AddRPCLog(Const Sender : String; Const Message : String);
    Function GetNewCallCounter : Int64;
  public
    Constructor Create;
    Destructor Destroy; override;
    Property Port : Word read FPort Write FPort;
    Property Active : Boolean read FActive write SetActive;
    Property WalletKeys : TWalletKeysExt read FWalletKeys write FWalletKeys;
    //
    Property JSON20Strict : Boolean read FJSON20Strict write FJSON20Strict;
    Property IniFileName : String read FIniFileName write SetIniFileName;
    Property LogFileName : String read GetLogFileName write SetLogFileName;
    Property ValidIPs : String read FValidIPs write SetValidIPs;
    Property AllowUsePrivateKeys : Boolean read FAllowUsePrivateKeys write FAllowUsePrivateKeys; // New v4 protection for free access server
    Property Node : TNode read FNode;
    //
    Function CheckAndGetPrivateKeyInWallet(const APublicKey : TAccountKey; var APrivateKey : TECPrivateKey; Var AErrorNum : Integer; Var AErrorDesc : String) : Boolean;
    Function GetMempoolAccount(AAccountNumber : Cardinal; var AAccount : TAccount) : Boolean;
  end;

  { TRPCServerThread }

  TRPCServerThread = Class(TPCThread)
    FRPCServer : TRPCServer;
    FServerSocket:TTCPBlockSocket;
    FPort : Word;
  protected
    procedure BCExecute; override;
  public
    Constructor Create(ARPCServer : TRPCServer; APort : Word);
    Destructor Destroy; Override;
  End;

  { TRPCProcess }

  TRPCProcess = class;
  TRPCProcessMethod = function(const ASender : TRPCProcess; const AMethodName : String; AInputParams, AJSONResponse : TPCJSONObject; var AErrorNum : Integer; var AErrorDesc : String) : Boolean of object;

  TRPCProcess = class(TPCThread)
  private
    FSock:TTCPBlockSocket;
    FNode : TNode;
    FRPCServer : TRPCServer;
  public
    Constructor Create (ARPCServer : TRPCServer; AHSock:tSocket);
    Destructor Destroy; override;
    procedure BCExecute; override;
    function ProcessMethod(Const method : String; params : TPCJSONObject; jsonresponse : TPCJSONObject; Var ErrorNum : Integer; Var ErrorDesc : String) : Boolean;
    property Node : TNode read FNode;
    property RPCServer : TRPCServer read FRPCServer;
    class procedure RegisterProcessMethod(Const AMethodName : String; ARPCProcessMethod : TRPCProcessMethod);
    class procedure UnregisterProcessMethod(Const AMethodName : String);
    class function FindRegisteredProcessMethod(Const AMethodName : String) : TRPCProcessMethod;
  end;


implementation

Uses  {$IFNDEF FPC}windows,{$ENDIF}
  SysUtils, Synautil,
  UPCRPCOpData, UPCRPCFindAccounts;

Type
  TRegisteredRPCProcessMethod = Record
    MethodName : String;
    RPCProcessMethod : TRPCProcessMethod;
  end;

var _RPCServer : TRPCServer = Nil;

  _RPCProcessMethods : TList<TRegisteredRPCProcessMethod> = Nil;

{ TPascalCoinJSONComp }

class procedure TPascalCoinJSONComp.FillBlockObject(nBlock : Cardinal; ANode : TNode; jsonObject: TPCJSONObject);
var pcops : TPCOperationsComp;
  ob : TOperationBlock;
begin
  pcops := TPCOperationsComp.Create(Nil);
  try
    If ANode.Bank.BlocksCount<=nBlock then begin
      Exit;
    end;
    ob := ANode.Bank.SafeBox.GetBlockInfo(nBlock);

    jsonObject.GetAsVariant('block').Value:=ob.block;
    jsonObject.GetAsVariant('enc_pubkey').Value := TCrypto.ToHexaString(TAccountComp.AccountKey2RawString(ob.account_key));
    jsonObject.GetAsVariant('reward').Value:=TAccountComp.FormatMoneyDecimal(ob.reward);
    jsonObject.GetAsVariant('reward_s').Value:=TAccountComp.FormatMoney(ob.reward);
    jsonObject.GetAsVariant('fee').Value:=TAccountComp.FormatMoneyDecimal(ob.fee);
    jsonObject.GetAsVariant('fee_s').Value:=TAccountComp.FormatMoney(ob.fee);
    jsonObject.GetAsVariant('ver').Value:=ob.protocol_version;
    jsonObject.GetAsVariant('ver_a').Value:=ob.protocol_available;
    jsonObject.GetAsVariant('timestamp').Value:=Int64(ob.timestamp);
    jsonObject.GetAsVariant('target').Value:=Int64(ob.compact_target);
    jsonObject.GetAsVariant('nonce').Value:=Int64(ob.nonce);
    jsonObject.GetAsVariant('payload').Value:=ob.block_payload.ToString;
    jsonObject.GetAsVariant('sbh').Value:=TCrypto.ToHexaString(ob.initial_safe_box_hash);
    jsonObject.GetAsVariant('oph').Value:=TCrypto.ToHexaString(ob.operations_hash);
    jsonObject.GetAsVariant('pow').Value:=TCrypto.ToHexaString(ob.proof_of_work);
    jsonObject.GetAsVariant('hashratekhs').Value := ANode.Bank.SafeBox.CalcBlockHashRateInKhs(ob.Block,50);
    jsonObject.GetAsVariant('maturation').Value := ANode.Bank.BlocksCount - ob.block - 1;
    If ANode.Bank.LoadOperations(pcops,nBlock) then begin
      jsonObject.GetAsVariant('operations').Value:=pcops.Count;
    end;
  finally
    pcops.Free;
  end;
end;

class procedure TPascalCoinJSONComp.FillOperationObject(const OPR: TOperationResume; currentNodeBlocksCount : Cardinal; jsonObject: TPCJSONObject);
Var i : Integer;
  LOpChangeAccountInfoType : TOpChangeAccountInfoType;
  LString : String;
  jsonArr : TPCJSONArray;
  auxObj : TPCJSONObject;

  procedure FillOpDataObject(AParentObj : TPCJSONObject; const AOpData : TMultiOpData);
  var LDataObj : TPCJSONObject;
  begin
    LDataObj := AParentObj.GetAsObject('data');
    LDataObj.GetAsVariant('id').Value := AOpData.ID.ToString; // Note: Delphi always return with brackets
    LDataObj.GetAsVariant('sequence').Value := AOpData.Sequence;
    LDataObj.GetAsVariant('type').Value := AOpData.&Type;
  end;

Begin
  if Not OPR.valid then begin
    jsonObject.GetAsVariant('valid').Value := OPR.valid;
  end;
  if (OPR.errors<>'') And (Not OPR.valid) then begin
    jsonObject.GetAsVariant('errors').Value := OPR.errors;
  end;
  if OPR.valid then begin
    jsonObject.GetAsVariant('block').Value:=OPR.Block;
    jsonObject.GetAsVariant('time').Value:=OPR.time;
    jsonObject.GetAsVariant('opblock').Value:=OPR.NOpInsideBlock;
    if (OPR.Block>0) And (OPR.Block<currentNodeBlocksCount) then
      jsonObject.GetAsVariant('maturation').Value := currentNodeBlocksCount - OPR.Block - 1
    else jsonObject.GetAsVariant('maturation').Value := null;
  end;
  jsonObject.GetAsVariant('optype').Value:=OPR.OpType;
  jsonObject.GetAsVariant('subtype').Value:=OPR.OpSubtype;
  If (Not OPR.isMultiOperation) then Begin
    jsonObject.GetAsVariant('account').Value:=OPR.AffectedAccount;
    jsonObject.GetAsVariant('signer_account').Value:=OPR.SignerAccount;
    if (OPR.n_operation>0) then jsonObject.GetAsVariant('n_operation').Value:=OPR.n_operation;
  end;
  // New V3: Will include senders[], receivers[] and changers[]
    jsonArr := jsonObject.GetAsArray('senders');
    for i:=Low(OPR.senders) to High(OPR.Senders) do begin
      auxObj := jsonArr.GetAsObject(jsonArr.Count);
      auxObj.GetAsVariant('account').Value := OPR.Senders[i].Account;
      if (OPR.Senders[i].N_Operation>0) then auxObj.GetAsVariant('n_operation').Value := OPR.Senders[i].N_Operation;
      auxObj.GetAsVariant('amount').Value := TAccountComp.FormatMoneyDecimal(OPR.Senders[i].Amount * (-1));
      auxObj.GetAsVariant('amount_s').Value := TAccountComp.FormatMoney (OPR.Senders[i].Amount * (-1));
      auxObj.GetAsVariant('payload').Value := TCrypto.ToHexaString(OPR.Senders[i].Payload.payload_raw);
      auxObj.GetAsVariant('payload_type').Value := OPR.Senders[i].Payload.payload_type;
      if (OPR.OpType = CT_Op_Data) then begin
        FillOpDataObject(auxObj, OPR.senders[i].OpData);
      end;
    end;
    //
    jsonArr := jsonObject.GetAsArray('receivers');
    for i:=Low(OPR.Receivers) to High(OPR.Receivers) do begin
      auxObj := jsonArr.GetAsObject(jsonArr.Count);
      auxObj.GetAsVariant('account').Value := OPR.Receivers[i].Account;
      auxObj.GetAsVariant('amount').Value :=  TAccountComp.FormatMoneyDecimal(OPR.Receivers[i].Amount);
      auxObj.GetAsVariant('amount_s').Value :=  TAccountComp.FormatMoney(OPR.Receivers[i].Amount);
      auxObj.GetAsVariant('payload').Value := TCrypto.ToHexaString(OPR.Receivers[i].Payload.payload_raw);
      auxObj.GetAsVariant('payload_type').Value := OPR.Receivers[i].Payload.payload_type;
    end;
    jsonArr := jsonObject.GetAsArray('changers');
    for i:=Low(OPR.Changers) to High(OPR.Changers) do begin
      auxObj := jsonArr.GetAsObject(jsonArr.Count);
      auxObj.GetAsVariant('account').Value := OPR.Changers[i].Account;
      if (OPR.Changers[i].N_Operation>0) then auxObj.GetAsVariant('n_operation').Value := OPR.Changers[i].N_Operation;
      If (public_key in OPR.Changers[i].Changes_type) then begin
        auxObj.GetAsVariant('new_enc_pubkey').Value := TCrypto.ToHexaString(TAccountComp.AccountKey2RawString(OPR.Changers[i].New_Accountkey));
      end;
      If account_name in OPR.Changers[i].Changes_type then begin
        auxObj.GetAsVariant('new_name').Value := OPR.Changers[i].New_Name.ToPrintable;
      end;
      If account_type in OPR.Changers[i].Changes_type then begin
        auxObj.GetAsVariant('new_type').Value := OPR.Changers[i].New_Type;
      end;
      If account_data in OPR.Changers[i].Changes_type then begin
        auxObj.GetAsVariant('new_data').Value := OPR.Changers[i].New_Data.ToHexaString;
      end;
      if (list_for_public_sale in OPR.Changers[i].Changes_type)
         or (list_for_private_sale in OPR.Changers[i].Changes_type)
         or (list_for_account_swap in OPR.Changers[i].Changes_type)
         or (list_for_coin_swap in OPR.Changers[i].Changes_type) then begin
        auxObj.GetAsVariant('seller_account').Value := OPR.Changers[i].Seller_Account;
        auxObj.GetAsVariant('account_price').Value := TAccountComp.FormatMoneyDecimal(OPR.Changers[i].Account_Price);
        auxObj.GetAsVariant('account_price_s').Value := TAccountComp.FormatMoney(OPR.Changers[i].Account_Price);
        auxObj.GetAsVariant('locked_until_block').Value := OPR.Changers[i].Locked_Until_Block;
        if (list_for_private_sale in OPR.Changers[i].Changes_type)
          or (list_for_account_swap in OPR.Changers[i].Changes_type) then begin
          auxObj.GetAsVariant('new_enc_pubkey').Value := TCrypto.ToHexaString(TAccountComp.AccountKey2RawString(OPR.Changers[i].New_Accountkey));
        end;
        if (list_for_account_swap in OPR.Changers[i].Changes_type)
          or (list_for_coin_swap in OPR.Changers[i].Changes_type) then begin
          auxObj.GetAsVariant('hashed_secret').Value := OPR.Changers[i].Hashed_secret.ToHexaString;
        end;
      end;
      if (OPR.Changers[i].Fee<>0) then begin
        auxObj.GetAsVariant('fee').Value := TAccountComp.FormatMoneyDecimal(OPR.Changers[i].Fee * (-1));
        auxObj.GetAsVariant('fee_s').Value := TAccountComp.FormatMoney(OPR.Changers[i].Fee * (-1));
      end;
      LString := '';
      for LOpChangeAccountInfoType := Low(LOpChangeAccountInfoType) to High(LOpChangeAccountInfoType) do begin
        if (LOpChangeAccountInfoType in OPR.Changers[i].Changes_type) then begin
          if LString<>'' then LString := LString + ',';
          LString := LString + CT_TOpChangeAccountInfoType_Txt[LOpChangeAccountInfoType];
        end;
      end;
      if LString<>'' then begin
        auxObj.GetAsVariant('changes').Value := LString;
      end;
    end;
  jsonObject.GetAsVariant('optxt').Value:=OPR.OperationTxt;
  jsonObject.GetAsVariant('fee').Value:=TAccountComp.FormatMoneyDecimal(OPR.Fee);
  jsonObject.GetAsVariant('fee_s').Value:=TAccountComp.FormatMoney(OPR.Fee);
  jsonObject.GetAsVariant('amount').Value:=TAccountComp.FormatMoneyDecimal(OPR.Amount);
  jsonObject.GetAsVariant('amount_s').Value:=TAccountComp.FormatMoney(OPR.Amount);
  if (Not OPR.isMultiOperation) then begin
    jsonObject.GetAsVariant('payload').Value:=TCrypto.ToHexaString(OPR.OriginalPayload.payload_raw);
    jsonObject.GetAsVariant('payload_type').Value := OPR.OriginalPayload.payload_type;
  end;
  if (OPR.Balance>=0) And (OPR.valid) then jsonObject.GetAsVariant('balance').Value:=TAccountComp.FormatMoneyDecimal(OPR.Balance);
  If (OPR.OpType = CT_Op_Transaction) then begin
    If OPR.SignerAccount>=0 then begin
      jsonObject.GetAsVariant('sender_account').Value:=OPR.SignerAccount;
    end;
    If OPR.DestAccount>=0 then begin
      jsonObject.GetAsVariant('dest_account').Value:=OPR.DestAccount;
    end;
  end;
  If OPR.newKey.EC_OpenSSL_NID>0 then begin
    jsonObject.GetAsVariant('enc_pubkey').Value := TCrypto.ToHexaString(TAccountComp.AccountKey2RawString(OPR.newKey));
  end;
  if (OPR.valid) And (Length(OPR.OperationHash)>0) then begin
    jsonObject.GetAsVariant('ophash').Value := TCrypto.ToHexaString(OPR.OperationHash);
    if (OPR.Block<CT_Protocol_Upgrade_v2_MinBlock) then begin
      jsonObject.GetAsVariant('old_ophash').Value := TCrypto.ToHexaString(OPR.OperationHash_OLD);
    end;
  end;
end;

class function TPascalCoinJSONComp.CapturePubKey(
  const AInputParams: TPCJSONObject; const APrefix: String;
  var APubKey: TAccountKey; var AErrortxt: String): Boolean;
var LErrors_aux : String;
  LAuxpubkey : TAccountKey;
begin
  APubKey := CT_Account_NUL.accountInfo.accountKey;
  AErrortxt := '';
  Result := false;
  //
  if (AInputParams.IndexOfName(APrefix+'b58_pubkey')>=0) then begin
    If Not TAccountComp.AccountPublicKeyImport(AInputParams.AsString(APrefix+'b58_pubkey',''),APubKey,Lerrors_aux) then begin
      AErrortxt:= 'Invalid value of param "'+APrefix+'b58_pubkey": '+Lerrors_aux;
      Exit;
    end;
    if (AInputParams.IndexOfName(APrefix+'enc_pubkey')>=0) then begin
      LAuxpubkey := TAccountComp.RawString2Accountkey(TCrypto.HexaToRaw(AInputParams.AsString(APrefix+'enc_pubkey','')));
      if (Not TAccountComp.EqualAccountKeys(LAuxpubkey,APubKey)) then begin
        AErrortxt := 'Params "'+APrefix+'b58_pubkey" and "'+APrefix+'enc_pubkey" public keys are not the same public key';
        exit;
      end;
    end;
  end else begin
    if (AInputParams.IndexOfName(APrefix+'enc_pubkey')<0) then begin
      AErrortxt := 'Need param "'+APrefix+'enc_pubkey" or "'+APrefix+'b58_pubkey"';
      exit;
    end;
    APubKey := TAccountComp.RawString2Accountkey(TCrypto.HexaToRaw(AInputParams.AsString(APrefix+'enc_pubkey','')));
  end;
  // Final confirmation
  If Not TAccountComp.IsValidAccountKey(APubKey,CT_BUILD_PROTOCOL,LErrors_aux) then begin
    AErrortxt := 'Invalid public key: '+LErrors_aux;
  end else Result := True;
end;

class function TPascalCoinJSONComp.CheckAndGetEncodedRAWPayload(
  const ARawPayload: TRawBytes; const APayload_method, AEncodePwdForAES: String;
  const ASenderAccounKey, ATargetAccountKey: TAccountKey;
  out AOperationPayload : TOperationPayload; var AErrorNum: Integer;
  var AErrorDesc: String): Boolean;
begin
  AOperationPayload := CT_TOperationPayload_NUL;
  // XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  // TODO:
  // Needs to assign AOperationPayload.payload_type based on PIP-0027
  // XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  if (Length(ARawPayload)>0) then begin
    if (APayload_method='none') then begin
      AOperationPayload.payload_raw:=ARawPayload;
      Result := True;
    end else if (APayload_method='dest') then begin
      Result := TPCEncryption.DoPascalCoinECIESEncrypt(ATargetAccountKey,ARawPayload,AOperationPayload.payload_raw);
    end else if (APayload_method='sender') then begin
      Result := TPCEncryption.DoPascalCoinECIESEncrypt(ASenderAccounKey,ARawPayload,AOperationPayload.payload_raw);
    end else if (APayload_method='aes') then begin
      AOperationPayload.payload_raw := TPCEncryption.DoPascalCoinAESEncrypt(ARawPayload,TEncoding.ANSI.GetBytes(AEncodePwdForAES));
      Result := True;
    end else begin
      Result := False;
      AErrorNum:=CT_RPC_ErrNum_InvalidOperation;
      AErrorDesc:='Invalid encode payload method: '+APayload_method;
      Exit;
    end;
  end else begin
    Result := True;
  end;
end;

class procedure TPascalCoinJSONComp.FillAccountObject(const account: TAccount; jsonObj: TPCJSONObject);
Begin
  jsonObj.GetAsVariant('account').Value:=account.account;
  jsonObj.GetAsVariant('enc_pubkey').Value := TCrypto.ToHexaString(TAccountComp.AccountKey2RawString(account.accountInfo.accountKey));
  jsonObj.GetAsVariant('balance').Value:=TAccountComp.FormatMoneyDecimal(account.balance);
  jsonObj.GetAsVariant('balance_s').Value:=TAccountComp.FormatMoney(account.balance);
  jsonObj.GetAsVariant('n_operation').Value:=account.n_operation;
  jsonObj.GetAsVariant('updated_b').Value:=account.GetLastUpdatedBlock;
  jsonObj.GetAsVariant('updated_b_active_mode').Value:=account.updated_on_block_active_mode;
  jsonObj.GetAsVariant('updated_b_passive_mode').Value:=account.updated_on_block_passive_mode;
  case account.accountInfo.state of
    as_Normal : jsonObj.GetAsVariant('state').Value:='normal';
    as_ForSale : begin
      jsonObj.GetAsVariant('state').Value:='listed';
      jsonObj.GetAsVariant('locked_until_block').Value:=account.accountInfo.locked_until_block;
      jsonObj.GetAsVariant('price').Value:=TAccountComp.FormatMoneyDecimal(account.accountInfo.price);
      jsonObj.GetAsVariant('price_s').Value:=TAccountComp.FormatMoney(account.accountInfo.price);
      jsonObj.GetAsVariant('seller_account').Value:=account.accountInfo.account_to_pay;
      jsonObj.GetAsVariant('private_sale').Value:= (account.accountInfo.new_publicKey.EC_OpenSSL_NID<>0);
      if not (account.accountInfo.new_publicKey.EC_OpenSSL_NID<>0) then begin
        jsonObj.GetAsVariant('new_enc_pubkey').Value := TCrypto.ToHexaString(TAccountComp.AccountKey2RawString(account.accountInfo.new_publicKey));
      end;
    end;
    as_ForAtomicAccountSwap : begin
      jsonObj.GetAsVariant('state').Value:='account_swap';
      jsonObj.GetAsVariant('locked_until_block').Value:=account.accountInfo.locked_until_block;
      jsonObj.GetAsVariant('new_enc_pubkey').Value := TCrypto.ToHexaString(TAccountComp.AccountKey2RawString(account.accountInfo.new_publicKey));
      jsonObj.GetAsVariant('hashed_secret').Value := account.accountInfo.hashed_secret.ToHexaString;
    end;
    as_ForAtomicCoinSwap : begin
      jsonObj.GetAsVariant('state').Value:='coin_swap';
      jsonObj.GetAsVariant('locked_until_block').Value:=account.accountInfo.locked_until_block;
      jsonObj.GetAsVariant('amount_to_swap').Value:=TAccountComp.FormatMoneyDecimal(account.accountInfo.price);
      jsonObj.GetAsVariant('amount_to_swap_s').Value:=TAccountComp.FormatMoney(account.accountInfo.price);
      jsonObj.GetAsVariant('receiver_swap_account').Value:=account.accountInfo.account_to_pay;
      jsonObj.GetAsVariant('hashed_secret').Value := account.accountInfo.hashed_secret.ToHexaString;
    end;
  else raise Exception.Create('ERROR DEV 20170425-1');
  end;
  jsonObj.GetAsVariant('name').Value := account.name.ToPrintable;
  jsonObj.GetAsVariant('type').Value := account.account_type;
  jsonObj.GetAsVariant('data').Value := account.account_data.ToHexaString;
  jsonObj.GetAsVariant('seal').Value := account.account_seal.ToHexaString;
end;

class procedure TPascalCoinJSONComp.FillOperationsHashTreeObject(const OperationsHashTree: TOperationsHashTree; jsonObject: TPCJSONObject);
begin
  jsonObject.GetAsVariant('operations').Value:=OperationsHashTree.OperationsCount;
  jsonObject.GetAsVariant('amount').Value:=TAccountComp.FormatMoneyDecimal(OperationsHashTree.TotalAmount);
  jsonObject.GetAsVariant('amount_s').Value:=TAccountComp.FormatMoney(OperationsHashTree.TotalAmount);
  jsonObject.GetAsVariant('fee').Value:=TAccountComp.FormatMoneyDecimal(OperationsHashTree.TotalFee);
  jsonObject.GetAsVariant('fee_s').Value:=TAccountComp.FormatMoney(OperationsHashTree.TotalFee);
  jsonObject.GetAsVariant('rawoperations').Value:=OperationsHashTreeToHexaString(OperationsHashTree);
end;

class procedure TPascalCoinJSONComp.FillMultiOperationObject(current_protocol : Word; const multiOperation: TOpMultiOperation; jsonObject: TPCJSONObject);
Var i, nSigned, nNotSigned : Integer;
  opht : TOperationsHashTree;
  jsonArr : TPCJSONArray;
  auxObj : TPCJSONObject;
begin
  opht := TOperationsHashTree.Create;
  Try
    opht.AddOperationToHashTree(multiOperation);
    jsonObject.GetAsVariant('rawoperations').Value:=OperationsHashTreeToHexaString(opht);
  finally
    opht.Free;
  end;
  nSigned := 0; nNotSigned := 0;
  for i:=0 to High(multiOperation.Data.txSenders) do begin
    If (Length(multiOperation.Data.txSenders[i].Signature.r)>0) And  (Length(multiOperation.Data.txSenders[i].Signature.s)>0) then inc(nSigned)
    else inc(nNotSigned);
  end;
  for i:=0 to High(multiOperation.Data.changesInfo) do begin
    If (Length(multiOperation.Data.changesInfo[i].Signature.r)>0) And  (Length(multiOperation.Data.changesInfo[i].Signature.s)>0) then inc(nSigned)
    else inc(nNotSigned);
  end;
  //
  jsonArr := jsonObject.GetAsArray('senders');
  for i:=Low(multiOperation.Data.txSenders) to High(multiOperation.Data.txSenders) do begin
    auxObj := jsonArr.GetAsObject(jsonArr.Count);
    auxObj.GetAsVariant('account').Value := multiOperation.Data.txSenders[i].Account;
    auxObj.GetAsVariant('n_operation').Value := multiOperation.Data.txSenders[i].N_Operation;
    auxObj.GetAsVariant('amount').Value := TAccountComp.FormatMoneyDecimal(multiOperation.Data.txSenders[i].Amount * (-1));
    auxObj.GetAsVariant('payload').Value := TCrypto.ToHexaString(multiOperation.Data.txSenders[i].Payload.payload_raw);
    auxObj.GetAsVariant('payload_type').Value := multiOperation.Data.txSenders[i].Payload.payload_type;
  end;
  //
  jsonArr := jsonObject.GetAsArray('receivers');
  for i:=Low(multiOperation.Data.txReceivers) to High(multiOperation.Data.txReceivers) do begin
    auxObj := jsonArr.GetAsObject(jsonArr.Count);
    auxObj.GetAsVariant('account').Value := multiOperation.Data.txReceivers[i].Account;
    auxObj.GetAsVariant('amount').Value := TAccountComp.FormatMoneyDecimal(multiOperation.Data.txReceivers[i].Amount);
    auxObj.GetAsVariant('payload').Value := TCrypto.ToHexaString(multiOperation.Data.txReceivers[i].Payload.payload_raw);
    auxObj.GetAsVariant('payload_type').Value := multiOperation.Data.txReceivers[i].Payload.payload_type;
  end;
  jsonArr := jsonObject.GetAsArray('changers');
  for i:=Low(multiOperation.Data.changesInfo) to High(multiOperation.Data.changesInfo) do begin
    auxObj := jsonArr.GetAsObject(jsonArr.Count);
    auxObj.GetAsVariant('account').Value := multiOperation.Data.changesInfo[i].Account;
    auxObj.GetAsVariant('n_operation').Value := multiOperation.Data.changesInfo[i].N_Operation;
    If public_key in multiOperation.Data.changesInfo[i].Changes_type then begin
      auxObj.GetAsVariant('new_enc_pubkey').Value := TCrypto.ToHexaString(TAccountComp.AccountKey2RawString(multiOperation.Data.changesInfo[i].New_Accountkey));
    end;
    If account_name in multiOperation.Data.changesInfo[i].Changes_type then begin
      auxObj.GetAsVariant('new_name').Value := multiOperation.Data.changesInfo[i].New_Name.ToPrintable;
    end;
    If account_type in multiOperation.Data.changesInfo[i].Changes_type then begin
      auxObj.GetAsVariant('new_type').Value := multiOperation.Data.changesInfo[i].New_Type;
    end;
    If account_data in multiOperation.Data.changesInfo[i].Changes_type then begin
      auxObj.GetAsVariant('new_data').Value := multiOperation.Data.changesInfo[i].New_Data.ToHexaString;
    end;
  end;
  jsonObject.GetAsVariant('amount').Value:=TAccountComp.FormatMoneyDecimal( multiOperation.OperationAmount );
  jsonObject.GetAsVariant('fee').Value:=TAccountComp.FormatMoneyDecimal( multiOperation.OperationFee );
  // New params for third party signing: (3.0.2)
  if (current_protocol>CT_PROTOCOL_3) then begin
    jsonObject.GetAsVariant('digest').Value:=TCrypto.ToHexaString(multiOperation.GetDigestToSign);
  end;

  jsonObject.GetAsVariant('senders_count').Value:=Length(multiOperation.Data.txSenders);
  jsonObject.GetAsVariant('receivers_count').Value:=Length(multiOperation.Data.txReceivers);
  jsonObject.GetAsVariant('changesinfo_count').Value:=Length(multiOperation.Data.changesInfo);
  jsonObject.GetAsVariant('signed_count').Value:=nSigned;
  jsonObject.GetAsVariant('not_signed_count').Value:=nNotSigned;
  //
  jsonObject.GetAsVariant('signed_can_execute').Value:=(nSigned>0) And (nNotSigned=0);
end;

class procedure TPascalCoinJSONComp.FillPublicKeyObject(const PubKey: TAccountKey; jsonObj: TPCJSONObject);
begin
  jsonObj.GetAsVariant('ec_nid').Value := PubKey.EC_OpenSSL_NID;
  jsonObj.GetAsVariant('x').Value := TCrypto.ToHexaString(PubKey.x);
  jsonObj.GetAsVariant('y').Value := TCrypto.ToHexaString(PubKey.y);
  jsonObj.GetAsVariant('enc_pubkey').Value := TCrypto.ToHexaString(TAccountComp.AccountKey2RawString(PubKey));
  jsonObj.GetAsVariant('b58_pubkey').Value := TAccountComp.AccountPublicKeyExport(PubKey);
end;

class function TPascalCoinJSONComp.HexaStringToOperationsHashTree(
  const AHexaStringOperationsHashTree: String; ACurrentProtocol : Word;
  out AOperationsHashTree: TOperationsHashTree; var AErrors: String): Boolean;
var Lraw : TRawBytes;
  ms : TMemoryStream;
Begin
  Result := False;
  Lraw := TCrypto.HexaToRaw(AHexaStringOperationsHashTree);
  if (AHexaStringOperationsHashTree<>'') And (Length(Lraw)=0) then begin
    AErrors := 'Invalid HexaString as operations';
    exit;
  end;
  ms := TMemoryStream.Create;
  Try
    ms.WriteBuffer(Lraw[Low(Lraw)],Length(Lraw));
    ms.Position := 0;
    AOperationsHashTree := TOperationsHashTree.Create;
    if (Length(Lraw)>0) then begin
      If not AOperationsHashTree.LoadOperationsHashTreeFromStream(ms,False,ACurrentProtocol,ACurrentProtocol,Nil,AErrors) then begin
        FreeAndNil(AOperationsHashTree);
        Exit;
      end;
    end;
    Result := true;
  Finally
    ms.Free;
  End;
end;

class function TPascalCoinJSONComp.OperationsHashTreeToHexaString(const OperationsHashTree: TOperationsHashTree): String;
var ms : TMemoryStream;
  raw : TRawBytes;
Begin
  ms := TMemoryStream.Create;
  Try
    OperationsHashTree.SaveOperationsHashTreeToStream(ms,false);
    ms.Position := 0;
    SetLength(raw,ms.Size);
    ms.ReadBuffer(raw[Low(raw)],ms.Size);
    Result := TCrypto.ToHexaString(raw);
  Finally
    ms.Free;
  End;
end;

class function TPascalCoinJSONComp.ToPascalCoins(jsonCurr: Real): Int64;
begin
  Result := Round(jsonCurr * 10000);
end;

{ TRPCServer }

Procedure TRPCServer.AddRPCLog(Const Sender : String; Const Message : String);
Begin
  If Not Assigned(FRPCLog) then exit;
  FRPCLog.NotifyNewLog(ltinfo,Sender+' '+Inttostr(FCallsCounter),Message);
end;

Function TRPCServer.GetLogFileName : String;
Begin
  If Assigned(FRPCLog) then
    Result := FRPCLog.FileName
  else Result := '';
end;

function TRPCServer.GetMempoolAccount(AAccountNumber: Cardinal; var AAccount: TAccount): Boolean;
begin
  if (AAccountNumber<0) Or (AAccountNumber>=Node.Bank.AccountsCount) then begin
    AAccount := CT_Account_NUL;
    Result := False;
  end else begin
    AAccount := Node.GetMempoolAccount(AAccountNumber);
    Result := True;
  end;
end;

function TRPCServer.GetNewCallCounter: Int64;
begin
  inc(FCallsCounter);
  Result := FCallsCounter;
end;

procedure TRPCServer.SetActive(AValue: Boolean);
begin
  if FActive=AValue then Exit;
  FActive:=AValue;
  if (FActive) then begin
    FRPCServerThread := TRPCServerThread.Create(Self,FPort);
  end else begin
    FRPCServerThread.Terminate;
    FRPCServerThread.WaitFor;
    FreeAndNil(FRPCServerThread);
  end;
  TLog.NewLog(ltupdate,Classname,'Updated RPC Server to Active='+CT_TRUE_FALSE[FActive]);
end;

procedure TRPCServer.SetIniFileName(const Value: String);
begin
  if FIniFileName=Value then exit;
  FreeAndNil(FIniFile);
  FIniFileName := Value;
  if (FIniFileName<>'') And (FileExists(FIniFileName)) then begin
    FIniFile := TIniFile.Create(FIniFileName);
  end;
  if Assigned(FIniFile) then begin
    FJSON20Strict := FIniFile.ReadBool('general','json20strict',true)
  end;
end;

procedure TRPCServer.SetLogFileName(const Value: String);
begin
  If (Not Assigned(FRPCLog)) And (Trim(Value)<>'') then begin
    FRPCLog := TLog.Create(Nil);
    FRPCLog.ProcessGlobalLogs:=false;
    FRPCLog.SaveTypes:=CT_TLogTypes_ALL;
  end;
  If (trim(Value)<>'') then begin
    FRPCLog.FileName:=Value;
  end else FreeAndNil(FRPCLog);
end;

procedure TRPCServer.SetValidIPs(const Value: String);
begin
  if FValidIPs=Value then exit;
  FValidIPs := Value;
  if FValidIPs='' then begin
    TLog.NewLog(ltupdate,Classname,'Updated RPC Server valid IPs to ALL');
    // New Build 3.0.2
    FAllowUsePrivateKeys := True; // By default, when opening RPC server to all IP's, use of private keys is forbidden to protect server
  end else TLog.NewLog(ltupdate,Classname,'Updated RPC Server valid IPs to: '+FValidIPs)
end;

function TRPCServer.IsValidClientIP(const clientIp: String; clientPort: Word): Boolean;
begin
  if FValidIPs='' then Result := true
  else begin
    Result := pos(clientIP,FValidIPs) > 0;
  end;
end;

function TRPCServer.CheckAndGetPrivateKeyInWallet(const APublicKey : TAccountKey; var APrivateKey : TECPrivateKey; Var AErrorNum : Integer; Var AErrorDesc : String) : Boolean;
var i : Integer;
begin
  Result := False;
  APrivateKey := Nil;
  i := FWalletKeys.IndexOfAccountKey(APublicKey);
  if i<0 then begin
    AErrorDesc := 'Sender Public Key not found in wallet: '+TAccountComp.AccountPublicKeyExport(APublicKey);
    AErrorNum := CT_RPC_ErrNum_InvalidPubKey;
    Exit;
  end;
  APrivateKey := FWalletKeys.Key[i].PrivateKey;
  if (Not assigned(APrivateKey)) then begin
    if Length(FWalletKeys.Key[i].CryptedKey)>0 then begin
      // Wallet is password protected
      AErrorDesc := 'Wallet is password protected';
      AErrorNum := CT_RPC_ErrNum_WalletPasswordProtected;
    end else begin
      AErrorDesc := 'Wallet private key not found in Wallet';
      AErrorNum := CT_RPC_ErrNum_InvalidPubKey;
    end;
  end else Result := True;
end;

constructor TRPCServer.Create;
begin
  FActive := false;
  FRPCLog := Nil;
  FIniFile := Nil;
  FIniFileName := '';
  FJSON20Strict := true;
  FWalletKeys := Nil;
  FRPCServerThread := Nil;
  FPort := CT_JSONRPC_Port;
  FCallsCounter := 0;
  FValidIPs := ''; // New Build 1.5 - By default, only localhost can access to RPC
  FAllowUsePrivateKeys := True;       // New Build 3.0.2 - By default RPC allows to use private keys functions
  FNode := TNode.Node;
  If Not assigned(_RPCServer) then _RPCServer := Self;
end;

destructor TRPCServer.Destroy;
begin
  FreeAndNil(FRPCLog);
  active := false;
  if _RPCServer=Self then _RPCServer:=Nil;
  inherited Destroy;
end;

{ TRPCProcess }

constructor TRPCProcess.Create(ARPCServer : TRPCServer; AHSock:tSocket);
begin
  FRPCServer := ARPCServer;
  FSock:=TTCPBlockSocket.create;
  FSock.socket:=AHSock;
  FreeOnTerminate:=true;
  FNode := TNode.Node;
  //Priority:=tpNormal;
  inherited create(True);
  FreeOnTerminate:=true;
  Suspended := False;
end;

destructor TRPCProcess.Destroy;
begin
  FSock.free;
  inherited Destroy;
end;

class function TRPCProcess.FindRegisteredProcessMethod(const AMethodName: String): TRPCProcessMethod;
var i : Integer;
begin
  Result := Nil;
  if Not Assigned(_RPCProcessMethods) then Exit;
  i := 0;
  while (i<_RPCProcessMethods.Count) and (Not Assigned(Result)) do begin
    if AnsiSameStr( _RPCProcessMethods.Items[i].MethodName , AMethodName) then begin
      Result := _RPCProcessMethods.Items[i].RPCProcessMethod;
    end;
    inc(i);
  end;
end;

procedure TRPCProcess.BCExecute;
var
  timeout: integer;
  s: string;
  method, uri, protocol: string;
  size: integer;
  x, n: integer;
  resultcode: integer;
  inputdata : TRawBytes;
  js,jsresult : TPCJSONData;
  jsonobj,jsonresponse : TPCJSONObject;
  errNum : Integer; errDesc : String;
  jsonrequesttxt,
  jsonresponsetxt, methodName, paramsTxt : String;
  valid : Boolean;
  i : Integer;
  Headers : TStringList;
  tc : TTickCount;
  callcounter : Int64;
begin
  callcounter := _RPCServer.GetNewCallCounter;
  tc := TPlatform.GetTickCount;
  methodName := '';
  paramsTxt := '';
  // IP Protection
  If (Not _RPCServer.IsValidClientIP(FSock.GetRemoteSinIP,FSock.GetRemoteSinPort)) then begin
    TLog.NewLog(lterror,Classname,FSock.GetRemoteSinIP+':'+inttostr(FSock.GetRemoteSinPort)+' INVALID IP');
    _RPCServer.AddRPCLog(FSock.GetRemoteSinIP+':'+InttoStr(FSock.GetRemoteSinPort),' INVALID IP');
    exit;
  end;
  errNum := CT_RPC_ErrNum_InternalError;
  errDesc := 'No data';
  valid := false;
  SetLength(inputdata,0);
  Headers := TStringList.Create;
  jsonresponse := TPCJSONObject.Create;
  try
    timeout := 5000;
    resultcode:= 200;
    repeat
      //read request line
      s := Fsock.RecvString(timeout);
      if Fsock.lasterror <> 0 then Exit;
      if s = '' then Exit;
      method := Fetch(s, ' ');
      if (s = '') or (method = '') then  Exit;
      uri := Fetch(s, ' '); if uri = '' then  Exit;
      protocol := Fetch(s, ' ');
      headers.Clear;
      size := -1;
      //read request headers
      if protocol <> '' then begin
        if protocol.IndexOf('HTTP/1.1')<>0 then begin
          errDesc := 'Invalid protocol '+protocol;
          Exit;
        end;
        repeat
          s := Fsock.RecvString(Timeout);
          if Fsock.lasterror <> 0 then
            Exit;
          s := UpperCase(s);
          if s.IndexOf('CONTENT-LENGTH:')=0 then
            Size := StrToIntDef(SeparateRight(s, ' '), -1);
        until s = '';
      end;
      //recv document...
      if size >= 0 then begin
        setLength(inputdata,size);
        x := FSock.RecvBufferEx(InputData, Size, Timeout);
        if Fsock.lasterror <> 0 then
          Exit;
        if (x<>size) And (x>0) then
          setLength(inputdata,x);
      end else setlength(inputdata,0);
      jsonrequesttxt := inputdata.ToString;
      // Convert InputData to JSON object
      try
        js := TPCJSONData.ParseJSONValue(jsonrequesttxt);
      except
        On E:Exception do begin
          errDesc:='Error decoding JSON: '+E.Message;
          TLog.NewLog(lterror,Classname,FSock.GetRemoteSinIP+':'+inttostr(FSock.GetRemoteSinPort)+' Error decoding JSON: '+E.Message);
          exit;
        end;
      end;
      If Assigned(js) then begin
        try
          If (js is TPCJSONObject) then begin
            jsonobj := TPCJSONObject(js);
            errNum := 0;
            errDesc := '';
            try
              methodName := jsonobj.AsString('method','');
              paramsTxt := jsonobj.GetAsObject('params').ToJSON(false);
              {$IFDEF HIGHLOG}TLog.NewLog(ltinfo,Classname,FSock.GetRemoteSinIP+':'+inttostr(FSock.GetRemoteSinPort)+' Processing method '+methodName+' params '+paramsTxt);{$ENDIF}
              Valid := ProcessMethod(methodName,jsonobj.GetAsObject('params'),jsonresponse,errNum,errDesc);
              if not Valid then begin
                if (errNum<>0) or (errDesc<>'') then begin
                  jsonresponse.GetAsObject('error').GetAsVariant('code').Value:=errNum;
                  jsonresponse.GetAsObject('error').GetAsVariant('message').Value:=errDesc;
                end else begin
                  jsonresponse.GetAsObject('error').GetAsVariant('code').Value:=CT_RPC_ErrNum_InternalError;
                  jsonresponse.GetAsObject('error').GetAsVariant('message').Value:='Unknown error processing method';
                end;
              end;
            Except
              on E:Exception do begin
                TLog.NewLog(lterror,Classname,'Exception processing method'+methodName+' ('+E.ClassName+'): '+E.Message);
                jsonresponse.GetAsObject('error').GetAsVariant('code').Value:=CT_RPC_ErrNum_InternalError;
                jsonresponse.GetAsObject('error').GetAsVariant('message').Value:=E.Message;
                valid:=False;
              end;
            end;
            jsonresponse.GetAsVariant('id').Value:= jsonobj.GetAsVariant('id').Value;
            jsonresponse.GetAsVariant('jsonrpc').Value:= '2.0';
          end;
        finally
          js.free;
        end;
      end else begin
        TLog.NewLog(lterror,ClassName,FSock.GetRemoteSinIP+':'+inttostr(FSock.GetRemoteSinPort)+' Received data is not a JSON: '+jsonrequesttxt+' (length '+inttostr(length(jsonrequesttxt))+' bytes)');
      end;
    until (FSock.LastError <> 0) Or (protocol<>'');
  Finally
    try
      // Send result:
      if Fsock.lasterror = 0 then begin
        // Save JSON response:
        If (Not Valid) then begin
          if Not assigned(jsonresponse.FindName('error')) then begin
            jsonresponse.GetAsObject('error').GetAsVariant('code').Value:=errNum;
            jsonresponse.GetAsObject('error').GetAsVariant('message').Value:=errDesc;
          end;
        end;
        jsonresponsetxt := jsonresponse.ToJSON(false);
        Fsock.SendString(protocol + ' ' + IntTostr(ResultCode) + CRLF);
        if (protocol <> '') then begin
          headers.Add('Server: PascalCoin HTTP JSON-RPC Server');
          headers.Add('Content-Type: application/json;charset=utf-8');
          headers.Add('Content-length: ' + IntTostr(length(jsonresponsetxt)));
          headers.Add('Connection: close');
          headers.Add('Access-Control-Allow-Origin: *');
          headers.Add('Date: ' + Rfc822DateTime(now));
          headers.Add('');
          for n := 0 to headers.count - 1 do
            Fsock.sendstring(headers[n] + CRLF);
        end;
        if Fsock.lasterror = 0 then begin
          FSock.SendString(jsonresponsetxt);
        end;
      end;
      _RPCServer.AddRPCLog(FSock.GetRemoteSinIP+':'+InttoStr(FSock.GetRemoteSinPort),'Method:'+methodName+' Params:'+paramsTxt+' '+Inttostr(errNum)+':'+errDesc+' Time:'+FormatFloat('0.000',(TPlatform.GetElapsedMilliseconds(tc)/1000)));
    finally
      jsonresponse.free;
      Headers.Free;
    end;
  end;
end;

function TRPCProcess.ProcessMethod(const method: String; params: TPCJSONObject;
  jsonresponse: TPCJSONObject; var ErrorNum: Integer; var ErrorDesc: String): Boolean;
  var _ro : TPCJSONObject;
      _ra : TPCJSONArray;
  Function GetResultObject : TPCJSONObject;
  begin
    if not assigned(_ro) then begin
      _ro := jsonresponse.GetAsObject('result');
      _ra := Nil;
    end;
    Result := _ro;
  end;

  Function GetResultArray : TPCJSONArray;
  begin
    if not assigned(_ra) then begin
      _ra := jsonresponse.GetAsArray('result');
      _ro := Nil;
    end;
    Result := _ra;
  end;

  Function ToJSONCurrency(pascalCoins : Int64) : Real;
  Begin
    Result := RoundTo( pascalCoins / 10000 , -4);
  End;

  Function ToPascalCoins(jsonCurr : Real) : Int64;
  Begin
    Result := TPascalCoinJSONComp.ToPascalCoins(jsonCurr);
  End;

  Function HexaStringToOperationsHashTreeAndGetMultioperation(AProtocolVersion : Word; Const HexaStringOperationsHashTree : String; canCreateNewOne : Boolean; out OperationsHashTree : TOperationsHashTree; out multiOperation : TOpMultiOperation; var errors : String) : Boolean;
    { This function will return true only if HexaString contains only 1 operation and is a multioperation.
      Also, if "canCreateNewOne" is true and has no operations, then will create new one and return True
      }
  var op : TPCOperation;
  Begin
    multiOperation := Nil;
    Result := TPascalCoinJSONComp.HexaStringToOperationsHashTree(HexaStringOperationsHashTree,AProtocolVersion,OperationsHashTree,errors);
    If (Result) then begin
      Try
        If (OperationsHashTree.OperationsCount=0) And (canCreateNewOne) then begin
          multiOperation := TOpMultiOperation.Create(AProtocolVersion);
          OperationsHashTree.AddOperationToHashTree(multiOperation);
          multiOperation.Free;
          multiOperation := OperationsHashTree.GetOperation(0) as TOpMultiOperation;
        end else if (OperationsHashTree.OperationsCount=1) then begin
          op := OperationsHashTree.GetOperation(0);
          if (op is TOpMultiOperation) then multiOperation := op as TOpMultiOperation
          else errors := 'operation is not a multioperation';
        end else errors := 'No multioperation found';
      finally
        If (Not Assigned(multiOperation)) then begin
          FreeAndNil(OperationsHashTree);
          Result := false;
        end;
      end;
    end;
  End;

  Function GetBlock(nBlock : Cardinal; jsonObject : TPCJSONObject) : Boolean;
  begin
    If FNode.Bank.BlocksCount<=nBlock then begin
      ErrorNum := CT_RPC_ErrNum_InvalidBlock;
      ErrorDesc := 'Cannot load Block: '+IntToStr(nBlock);
      Result := False;
      Exit;
    end;
    TPascalCoinJSONComp.FillBlockObject(nBlock,FNode,jsonObject);
    Result := True;
  end;

  Procedure FillOperationResumeToJSONObject(Const OPR : TOperationResume; jsonObject : TPCJSONObject);
  Begin
    TPascalCoinJSONComp.FillOperationObject(OPR,FNode.Bank.BlocksCount,jsonObject);
  end;

  Function GetAccountOperations(accountNumber : Cardinal; jsonArray : TPCJSONArray; maxBlocksDepth, startReg, maxReg: Integer; forceStartBlock : Cardinal) : Boolean;
  var list : TList<Cardinal>;
    Op : TPCOperation;
    OPR : TOperationResume;
    Obj : TPCJSONObject;
    OperationsResume : TOperationsResumeList;
    i, nCounter : Integer;
    LLockedMempool : TPCOperationsComp;
  Begin
    Result := false;
    if (startReg<-1) or (maxReg<=0) then begin
      ErrorNum := CT_RPC_ErrNum_InvalidData;
      ErrorDesc := 'Invalid start or max value';
      Exit;
    end;
    nCounter := 0;
    OperationsResume := TOperationsResumeList.Create;
    try
      if ((startReg=-1) And (forceStartBlock=0)) then begin
        // 1.5.5 change: If start=-1 then will include PENDING OPERATIONS, otherwise not.
        // Only will return pending operations if start=0, otherwise
        list := TList<Cardinal>.Create;
        Try
          LLockedMempool := FNode.LockMempoolRead;
          try
            LLockedMempool.OperationsHashTree.GetOperationsAffectingAccount(accountNumber,list);
            for i := list.Count - 1 downto 0 do begin
              Op := LLockedMempool.OperationsHashTree.GetOperation(list[i]);
              If TPCOperation.OperationToOperationResume(0,Op,False,accountNumber,OPR) then begin
                OPR.NOpInsideBlock := i;
                OPR.Block := LLockedMempool.OperationBlock.block;
                OPR.Balance := LLockedMempool.SafeBoxTransaction.Account(accountNumber).balance;
                if (nCounter>=startReg) And (nCounter<maxReg) then begin
                  OperationsResume.Add(OPR);
                end;
                inc(nCounter);
              end;
            end;
          finally
            FNode.UnlockMempoolRead;
          end;
        Finally
          list.Free;
        End;
      end;
      if (nCounter<maxReg) then begin
        if (startReg<0) then startReg := 0; // Prevent -1 value
        FNode.GetStoredOperationsFromAccount(OperationsResume,accountNumber,maxBlocksDepth,startReg,startReg+maxReg-1,forceStartBlock);
      end;
      for i:=0 to OperationsResume.Count-1 do begin
        Obj := jsonArray.GetAsObject(jsonArray.Count);
        OPR := OperationsResume[i];
        FillOperationResumeToJSONObject(OPR,Obj);
      end;
      Result := True;
    finally
      OperationsResume.Free;
    end;
  end;

  Procedure GetConnections;
  var i : Integer;
    l : TList<TNetConnection>;
    nc : TNetConnection;
    obj: TPCJSONObject;
  Begin
    l := TNetData.NetData.NetConnections.LockList;
    try
      for i:=0 to l.Count-1 do begin
        nc := TNetData.NetData.Connection(i);
        obj := jsonresponse.GetAsArray('result').GetAsObject(i);
        obj.GetAsVariant('server').Value := Not (nc is TNetServerClient);
        obj.GetAsVariant('ip').Value:=nc.Client.RemoteHost;
        obj.GetAsVariant('port').Value:=nc.Client.RemotePort;
        obj.GetAsVariant('secs').Value:=UnivDateTimeToUnix(now) - UnivDateTimeToUnix(nc.CreatedTime);
        obj.GetAsVariant('sent').Value:=nc.Client.BytesSent;
        obj.GetAsVariant('recv').Value:=nc.Client.BytesReceived;
        obj.GetAsVariant('appver').Value:=nc.ClientAppVersion;
        obj.GetAsVariant('netver').Value:=nc.NetProtocolVersion.protocol_version;
        obj.GetAsVariant('netver_a').Value:=nc.NetProtocolVersion.protocol_available;
        obj.GetAsVariant('timediff').Value:=nc.TimestampDiff;
      end;
    finally
      TNetData.NetData.NetConnections.UnlockList;
    end;
  end;

  Procedure Get_node_ip_stats;
  var aip : String;
    i : Integer;
    json, newJson : TPCJSONObject;
    ipInfo : TIpInfo;
    aDisconnectedOnly : Boolean;
    LShowDetailedStats : Boolean;
  begin
    if params.AsBoolean('clean',False) then begin
      GetResultObject.GetAsVariant('cleaned').Value := TNetData.NetData.IpInfos.CleanLastStats;
      Exit;
    end;
    if params.AsBoolean('clear',False) then begin
      GetResultObject.GetAsVariant('cleared').Value := TNetData.NetData.IpInfos.Count;
      TNetData.NetData.IpInfos.Clear;
      Exit;
    end;
    LShowDetailedStats := params.AsBoolean('detailed-stats',False);
    aip := Trim(params.AsString('ip',''));
    if aip<>'' then begin
      json := TNetData.NetData.IpInfos.Lock(aip,False);
      Try
        newJson := TPCJSONObject.Create;
        newJson.GetAsVariant('ip').Value := aip;
        if LShowDetailedStats then begin
          newJson.GetAsObject('values').Assign(json);
        end;
        GetResultArray.Insert(GetResultArray.Count,newJson);
      Finally
        TNetData.NetData.IpInfos.Unlock;
      End;
    end else begin
      aDisconnectedOnly := params.AsBoolean('only-disconnected',False);
      for i :=0 to TNetData.NetData.IpInfos.Count-1 do begin
        ipInfo := TNetData.NetData.IpInfos.Lock(i);
        Try
          if (Not aDisconnectedOnly) Or (Assigned(ipInfo.json.FindName('disconnect'))) then begin
            newJson := TPCJSONObject.Create;
            newJson.GetAsVariant('ip').Value := ipInfo.ip;
            if LShowDetailedStats then begin
              newJson.GetAsObject('values').Assign(ipInfo.json);
            end;
            GetResultArray.Insert(GetResultArray.Count,newJson);
          end;
        Finally
          TNetData.NetData.IpInfos.Unlock;
        End;
      end;
    end;
  end;

  // This function creates a TOpTransaction without looking for balance/private key of sender account
  // It assumes that sender,target,sender_last_n_operation,senderAccountKey and targetAccountKey are correct
  Function CreateOperationTransaction(current_protocol : Word; sender, target, sender_last_n_operation : Cardinal; amount, fee : UInt64;
    Const senderAccounKey, targetAccountKey : TAccountKey; Const RawPayload : TRawBytes;
    Const Payload_method, EncodePwd : String) : TOpTransaction;
  // "payload_method" types: "none","dest"(default),"sender","aes"(must provide "pwd" param)
  Var LOpPayload : TOperationPayload;
    privateKey : TECPrivateKey;
  Begin
    Result := Nil;
    if Not RPCServer.CheckAndGetPrivateKeyInWallet(senderAccounKey,privateKey,ErrorNum,ErrorDesc) then Exit(Nil);
    if Not TPascalCoinJSONComp.CheckAndGetEncodedRAWPayload(RawPayload,Payload_method,EncodePwd,senderAccounKey,targetAccountKey,LOpPayload,ErrorNum,ErrorDesc) then Exit(Nil);
    Result := TOpTransaction.CreateTransaction(current_protocol, sender,sender_last_n_operation+1,target,privateKey,amount,fee,LOpPayload);
    if Not Result.HasValidSignature then begin
      FreeAndNil(Result);
      ErrorNum:=CT_RPC_ErrNum_InternalError;
      ErrorDesc:='Invalid signature';
      exit;
    end;
  End;

  Function CaptureAccountNumber(const AParamName : String; const ACheckAccountNumberExistsInSafebox : Boolean; var AAccountNumber : Cardinal; var AErrorParam : String) : Boolean;
  var LParamValue : String;
  Begin
    LParamValue := params.AsString(AParamName,'');
    if Length(LParamValue)>0 then begin
      Result := TAccountComp.AccountTxtNumberToAccountNumber(LParamValue,AAccountNumber);
      if Not Result then begin
        AErrorParam := Format('"%s" is no valid Account number for Param "%s"',[LParamValue,AParamName]);
      end else if (ACheckAccountNumberExistsInSafebox) then begin
        if (AAccountNumber<0) or (AAccountNumber>=FNode.Bank.AccountsCount) then begin
          Result := False;
          AErrorParam := Format('Account %d does not exist in safebox (param "%s")',[AAccountNumber,AParamName]);
        end;
      end;
    end else begin
      Result := False;
      AErrorParam := Format('Param "%s" not provided or null',[AParamName]);
    end;
  End;

  Function OpSendTo(sender, target : Cardinal; amount, fee : UInt64; Const RawPayload : TRawBytes; Const Payload_method, EncodePwd : String) : Boolean;
  // "payload_method" types: "none","dest"(default),"sender","aes"(must provide "pwd" param)
  Var opt : TOpTransaction;
    sacc,tacc : TAccount;
    errors : String;
    opr : TOperationResume;
  begin
    FNode.OperationSequenceLock.Acquire;  // Use lock to prevent N_Operation race-condition on concurrent sends
    try
      Result := false;
      if (sender<0) or (sender>=FNode.Bank.AccountsCount) then begin
        If (sender=CT_MaxAccount) then ErrorDesc := 'Need sender'
        else ErrorDesc:='Invalid sender account '+Inttostr(sender);
        ErrorNum:=CT_RPC_ErrNum_InvalidAccount;
        Exit;
      end;
      if (target<0) or (target>=FNode.Bank.AccountsCount) then begin
        If (target=CT_MaxAccount) then ErrorDesc := 'Need target'
        else ErrorDesc:='Invalid target account '+Inttostr(target);
        ErrorNum:=CT_RPC_ErrNum_InvalidAccount;
        Exit;
      end;
      sacc := FNode.GetMempoolAccount(sender);
      tacc := FNode.GetMempoolAccount(target);

      opt := CreateOperationTransaction(FNode.Bank.SafeBox.CurrentProtocol,sender,target,sacc.n_operation,amount,fee,sacc.accountInfo.accountKey,tacc.accountInfo.accountKey,RawPayload,Payload_method,EncodePwd);
      if opt=nil then exit;
      try
        If not FNode.AddOperation(Nil,opt,errors) then begin
          ErrorDesc := 'Error adding operation: '+errors;
          ErrorNum := CT_RPC_ErrNum_InvalidOperation;
          Exit;
        end;
        TPCOperation.OperationToOperationResume(0,opt,False,sender,opr);
        FillOperationResumeToJSONObject(opr,GetResultObject);
        Result := true;
      finally
        opt.free;
      end;
    finally
      FNode.OperationSequenceLock.Release;
    end;
  end;

  Function SignOpSendTo(Const HexaStringOperationsHashTree : String; current_protocol : Word;
    sender, target : Cardinal;
    Const senderAccounKey, targetAccountKey : TAccountKey;
    last_sender_n_operation : Cardinal;
    amount, fee : UInt64; Const RawPayload : TRawBytes; Const Payload_method, EncodePwd : String) : Boolean;
  // "payload_method" types: "none","dest"(default),"sender","aes"(must provide "pwd" param)
  var OperationsHashTree : TOperationsHashTree;
    errors : String;
    opt : TOpTransaction;
  begin
    Result := false;
    if Not TPascalCoinJSONComp.HexaStringToOperationsHashTree(HexaStringOperationsHashTree,current_protocol,OperationsHashTree,errors) then begin
      ErrorNum:=CT_RPC_ErrNum_InvalidData;
      ErrorDesc:= 'Error decoding param "rawoperations": '+errors;
      Exit;
    end;
    Try
      opt := CreateOperationTransaction(current_protocol, sender,target,last_sender_n_operation,amount,fee,senderAccounKey,targetAccountKey,RawPayload,Payload_method,EncodePwd);
      if opt=nil then exit;
      try
        OperationsHashTree.AddOperationToHashTree(opt);
        TPascalCoinJSONComp.FillOperationsHashTreeObject(OperationsHashTree,GetResultObject);
        Result := true;
      finally
        opt.Free;
      end;
    Finally
      OperationsHashTree.Free;
    End;
  end;

  // This function creates a TOpChangeKey without looking for private key of account
  // It assumes that account_signer,account_last_n_operation, account_target and account_pubkey are correct
  Function CreateOperationChangeKey(current_protocol : Word; account_signer, account_last_n_operation, account_target : Cardinal; const account_pubkey, new_pubkey : TAccountKey; fee : UInt64; RawPayload : TRawBytes; Const Payload_method, EncodePwd : String) : TOpChangeKey;
  // "payload_method" types: "none","dest"(default),"sender","aes"(must provide "pwd" param)
  var
    errors : String;
    LOpPayload : TOperationPayload;
    privateKey : TECPrivateKey;
  Begin
    Result := Nil;
    LOpPayload := CT_TOperationPayload_NUL;
    if Not RPCServer.CheckAndGetPrivateKeyInWallet(account_pubkey,privateKey,ErrorNum,ErrorDesc) then Exit(Nil);
    if Not TPascalCoinJSONComp.CheckAndGetEncodedRAWPayload(RawPayload,Payload_method,EncodePwd,account_pubkey,new_pubkey,LOpPayload,ErrorNum,ErrorDesc) then Exit(Nil);
    If account_signer=account_target then begin
      Result := TOpChangeKey.Create(current_protocol,account_signer,account_last_n_operation+1,account_target,privateKey,new_pubkey,fee,LOpPayload);
    end else begin
      Result := TOpChangeKeySigned.Create(current_protocol,account_signer,account_last_n_operation+1,account_target,privateKey,new_pubkey,fee,LOpPayload);
    end;
    if Not Result.HasValidSignature then begin
      FreeAndNil(Result);
      ErrorNum:=CT_RPC_ErrNum_InternalError;
      ErrorDesc:='Invalid signature';
      exit;
    end;
  End;

  Function ChangeAccountKey(account_signer, account_target : Cardinal; const new_pub_key : TAccountKey; fee : UInt64; const RawPayload : TRawBytes; Const Payload_method, EncodePwd : String) : Boolean;
  // "payload_method" types: "none","dest"(default),"sender","aes"(must provide "pwd" param)
  Var opck : TOpChangeKey;
    acc_signer : TAccount;
    errors : String;
    opr : TOperationResume;
  begin
    FNode.OperationSequenceLock.Acquire;  // Use lock to prevent N_Operation race-condition on concurrent invocations
    try
      Result := false;
      if (account_signer<0) or (account_signer>=FNode.Bank.AccountsCount) then begin
        ErrorDesc:='Invalid account '+Inttostr(account_signer);
        ErrorNum:=CT_RPC_ErrNum_InvalidAccount;
        Exit;
      end;
      acc_signer := FNode.GetMempoolAccount(account_signer);

      opck := CreateOperationChangeKey(FNode.Bank.SafeBox.CurrentProtocol,account_signer,acc_signer.n_operation,account_target,acc_signer.accountInfo.accountKey,new_pub_key,fee,RawPayload,Payload_method,EncodePwd);
      if not assigned(opck) then exit;
      try
        If not FNode.AddOperation(Nil,opck,errors) then begin
          ErrorDesc := 'Error adding operation: '+errors;
          ErrorNum := CT_RPC_ErrNum_InvalidOperation;
          Exit;
        end;
        TPCOperation.OperationToOperationResume(0,opck,False,account_signer,opr);
        FillOperationResumeToJSONObject(opr,GetResultObject);
        Result := true;
      finally
        opck.free;
      end;
    finally
      FNode.OperationSequenceLock.Release;
    end;
  end;

  // This function creates a TOpListAccountForSale without looking for actual state (cold wallet)
  // It assumes that account_number,account_last_n_operation and account_pubkey are correct
  Function CreateOperationListAccountForSale(current_protocol : Word; ANewAccountState : TAccountState; account_signer, account_last_n_operation, account_listed : Cardinal; const account_signer_pubkey: TAccountKey;
    account_price : UInt64; locked_until_block : Cardinal; account_to_pay : Cardinal; Const new_account_pubkey : TAccountKey;
    fee : UInt64; const AHashLock: T32Bytes; const RawPayload : TRawBytes; Const Payload_method, EncodePwd : String) : TOpListAccountForSaleOrSwap;
  // "payload_method" types: "none","dest"(default),"sender","aes"(must provide "pwd" param)
  var privateKey : TECPrivateKey;
    errors : String;
    LOpPayload : TOperationPayload;
    aux_target_pubkey : TAccountKey;
  Begin
    Result := Nil;
    if Not RPCServer.CheckAndGetPrivateKeyInWallet(account_signer_pubkey,privateKey,ErrorNum,ErrorDesc) then Exit(Nil);
    if (Payload_method='dest') And (new_account_pubkey.EC_OpenSSL_NID<>CT_TECDSA_Public_Nul.EC_OpenSSL_NID) then begin
        // If using 'dest', only will apply if there is a fixed new public key, otherwise will use current public key of account
       aux_target_pubkey := new_account_pubkey;
    end else aux_target_pubkey := account_signer_pubkey;
    if Not TPascalCoinJSONComp.CheckAndGetEncodedRAWPayload(RawPayload,Payload_method,EncodePwd,account_signer_pubkey,aux_target_pubkey,LOpPayload,ErrorNum,ErrorDesc) then Exit(Nil);
    Result := TOpListAccountForSaleOrSwap.CreateListAccountForSaleOrSwap(
      current_protocol,
      ANewAccountState,
      account_signer,
      account_last_n_operation+1,
      account_listed,
      account_price,
      fee,
      account_to_pay,
      new_account_pubkey,
      locked_until_block,
      privateKey,
      AHashLock,
      LOpPayload
    );
    if Not Result.HasValidSignature then begin
      FreeAndNil(Result);
      ErrorNum:=CT_RPC_ErrNum_InternalError;
      ErrorDesc:='Invalid signature';
      exit;
    end;
  End;

  // This function creates a TOpDelistAccountForSale without looking for actual state (cold wallet)
  // It assumes that account_number,account_last_n_operation are correct
  Function CreateOperationDelistAccountForSale(current_protocol : Word; account_signer, account_last_n_operation, account_delisted : Cardinal; const account_signer_pubkey: TAccountKey;
    fee : UInt64; RawPayload : TRawBytes; Const Payload_method, EncodePwd : String) : TOpDelistAccountForSale;
  // "payload_method" types: "none","dest"(default),"sender","aes"(must provide "pwd" param)
  var privateKey : TECPrivateKey;
    LOpPayload : TOperationPayload;
  Begin
    Result := Nil;
    LOpPayload := CT_TOperationPayload_NUL;
    if Not RPCServer.CheckAndGetPrivateKeyInWallet(account_signer_pubkey,privateKey,ErrorNum,ErrorDesc) then Exit(Nil);
    if Not TPascalCoinJSONComp.CheckAndGetEncodedRAWPayload(RawPayload,Payload_method,EncodePwd,account_signer_pubkey,account_signer_pubkey,LOpPayload,ErrorNum,ErrorDesc) then Exit(Nil);
    Result := TOpDelistAccountForSale.CreateDelistAccountForSale(current_protocol,account_signer,account_last_n_operation+1,account_delisted,fee,privateKey,LOpPayload);
    if Not Result.HasValidSignature then begin
      FreeAndNil(Result);
      ErrorNum:=CT_RPC_ErrNum_InternalError;
      ErrorDesc:='Invalid signature';
      exit;
    end;
  End;

  // This function creates a TOpBuyAccount without looking for actual state (cold wallet)
  // It assumes that account_number,account_last_n_operation and account_pubkey are correct
  // Also asumes that amount is >= price and other needed conditions
  Function CreateOperationBuyAccount(current_protocol : Word; account_number, account_last_n_operation : Cardinal; const account_pubkey: TAccountKey;
    account_to_buy : Cardinal; account_price, amount : UInt64; account_to_pay : Cardinal; Const new_account_pubkey : TAccountKey;
    fee : UInt64; RawPayload : TRawBytes; Const Payload_method, EncodePwd : String) : TOpBuyAccount;
  // "payload_method" types: "none","dest"(default),"sender","aes"(must provide "pwd" param)
  var privateKey : TECPrivateKey;
    errors : String;
    LOpPayload : TOperationPayload;
  Begin
    Result := Nil;
    if Not RPCServer.CheckAndGetPrivateKeyInWallet(account_pubkey,privateKey,ErrorNum,ErrorDesc) then Exit(Nil);
    if Not TPascalCoinJSONComp.CheckAndGetEncodedRAWPayload(RawPayload,Payload_method,EncodePwd,account_pubkey,new_account_pubkey,LOpPayload,ErrorNum,ErrorDesc) then Exit(Nil);
    Result := TOpBuyAccount.CreateBuy(current_protocol,account_number,account_last_n_operation+1,account_to_buy,account_to_pay,account_price,amount,fee,new_account_pubkey,privateKey,LOpPayload);
    if Not Result.HasValidSignature then begin
      FreeAndNil(Result);
      ErrorNum:=CT_RPC_ErrNum_InternalError;
      ErrorDesc:='Invalid signature';
      exit;
    end;
  End;

  Function GetCardinalsValues(ordinals_coma_separated : String; cardinals : TOrderedCardinalList; var errors : String) : Boolean;
  Var i,istart : Integer;
    ctxt : String;
    an : Cardinal;
  begin
    result := false;
    cardinals.Clear;
    errors := '';
    ctxt := '';
    istart := 1;
    for i := Low(ordinals_coma_separated) to High(ordinals_coma_separated) do begin
      case ordinals_coma_separated[i] of
        '0'..'9','-' : ctxt := ctxt + ordinals_coma_separated[i];
        ',',';' : begin
          if trim(ctxt)<>'' then begin
            if Not TAccountComp.AccountTxtNumberToAccountNumber(trim(ctxt),an) then begin
              errors := 'Invalid account number at pos '+IntToStr(istart)+': '+ctxt;
              exit;
            end;
            cardinals.Add(an);
          end;
          ctxt := '';
          istart := i+1;
        end;
        ' ' : ; // Continue...
      else
        errors := 'Invalid char at pos '+inttostr(i)+': "'+ordinals_coma_separated[i]+'"';
        exit;
      end;
    end;
    //
    if (trim(ctxt)<>'') then begin
      if Not TAccountComp.AccountTxtNumberToAccountNumber(trim(ctxt),an) then begin
        errors := 'Invalid account number at pos '+IntToStr(istart)+': '+ctxt;
        exit;
      end;
      cardinals.Add(an);
    end;
    if cardinals.Count=0 then begin
      errors := 'No valid value';
      exit;
    end;
    Result := true;
  end;

  Function ChangeAccountsKey(accounts_txt : String; const new_pub_key : TAccountKey; fee : UInt64; const RawPayload : TRawBytes; Const Payload_method, EncodePwd : String) : Boolean;
  // "payload_method" types: "none","dest"(default),"sender","aes"(must provide "pwd" param)
  Var opck : TOpChangeKey;
    acc : TAccount;
    i, ian : Integer;
    errors : String;
    opr : TOperationResume;
    accountsnumber : TOrderedCardinalList;
    operationsht : TOperationsHashTree;
    OperationsResumeList : TOperationsResumeList;
  begin
    FNode.OperationSequenceLock.Acquire;  // Use lock to prevent N_Operation race-condition on concurrent invocations
    try
      Result := false;
      accountsnumber := TOrderedCardinalList.Create;
      try
        if not GetCardinalsValues(accounts_txt,accountsnumber,errors) then begin
          ErrorDesc := 'Error in accounts: '+errors;
          ErrorNum := CT_RPC_ErrNum_InvalidAccount;
          Exit;
        end;
        operationsht := TOperationsHashTree.Create;
        try
          for ian := 0 to accountsnumber.Count - 1 do begin

            if (accountsnumber.Get(ian)<0) or (accountsnumber.Get(ian)>=FNode.Bank.AccountsCount) then begin
              ErrorDesc:='Invalid account '+Inttostr(accountsnumber.Get(ian));
              ErrorNum:=CT_RPC_ErrNum_InvalidAccount;
              Exit;
            end;
            acc := FNode.GetMempoolAccount(accountsnumber.Get(ian));
            opck := CreateOperationChangeKey(FNode.Bank.SafeBox.CurrentProtocol,acc.account,acc.n_operation,acc.account,acc.accountInfo.accountKey,new_pub_key,fee,RawPayload,Payload_method,EncodePwd);
            if not assigned(opck) then exit;
            try
              operationsht.AddOperationToHashTree(opck);
            finally
              opck.free;
            end;
          end; // For
          // Ready to execute...
          OperationsResumeList := TOperationsResumeList.Create;
          Try
            i := FNode.AddOperations(Nil,operationsht,OperationsResumeList, errors);
            if (i<0) then begin
              ErrorNum:=CT_RPC_ErrNum_InternalError;
              ErrorDesc:=errors;
              exit;
            end;
            GetResultArray.Clear; // Inits an array
            for i := 0 to OperationsResumeList.Count - 1 do begin
              FillOperationResumeToJSONObject(OperationsResumeList[i],GetResultArray.GetAsObject(i));
            end;
          Finally
            OperationsResumeList.Free;
          End;
          Result := true;
        finally
          operationsht.Free;
        end;
      finally
        accountsnumber.Free;
      end;
    finally
      FNode.OperationSequenceLock.Release;
    end;
  end;

  Function SignOpChangeKey(Const HexaStringOperationsHashTree : String; current_protocol : Word; account_signer, account_target : Cardinal;
    Const actualAccounKey, newAccountKey : TAccountKey;
    last_n_operation : Cardinal;
    fee : UInt64; Const RawPayload : TRawBytes; Const Payload_method, EncodePwd : String) : Boolean;
  // "payload_method" types: "none","dest"(default),"sender","aes"(must provide "pwd" param)
  var OperationsHashTree : TOperationsHashTree;
    errors : String;
    opck : TOpChangeKey;
  begin
    Result := false;
    if Not TPascalCoinJSONComp.HexaStringToOperationsHashTree(HexaStringOperationsHashTree,current_protocol,OperationsHashTree,errors) then begin
      ErrorNum:=CT_RPC_ErrNum_InvalidData;
      ErrorDesc:= 'Error decoding param "rawoperations": '+errors;
      Exit;
    end;
    Try
      opck := CreateOperationChangeKey(current_protocol,account_signer,last_n_operation,account_target,actualAccounKey,newAccountKey,fee,RawPayload,Payload_method,EncodePwd);
      if opck=nil then exit;
      try
        OperationsHashTree.AddOperationToHashTree(opck);
        TPascalCoinJSONComp.FillOperationsHashTreeObject(OperationsHashTree,GetResultObject);
        Result := true;
      finally
        opck.Free;
      end;
    Finally
      OperationsHashTree.Free;
    End;
  end;

  Function OperationsInfo(Const HexaStringOperationsHashTree : String; jsonArray : TPCJSONArray) : Boolean;
  var OperationsHashTree : TOperationsHashTree;
    errors : String;
    OPR : TOperationResume;
    Obj : TPCJSONObject;
    Op : TPCOperation;
    i : Integer;
  Begin
    Result := False;
    if Not TPascalCoinJSONComp.HexaStringToOperationsHashTree(HexaStringOperationsHashTree,CT_BUILD_PROTOCOL,OperationsHashTree,errors) then begin
      ErrorNum:=CT_RPC_ErrNum_InvalidData;
      ErrorDesc:= 'Error decoding param "rawoperations": '+errors;
      Exit;
    end;
    Try
      jsonArray.Clear;
      for i := 0 to OperationsHashTree.OperationsCount - 1 do begin
        Op := OperationsHashTree.GetOperation(i);
        Obj := jsonArray.GetAsObject(i);
        If TPCOperation.OperationToOperationResume(0,Op,True,Op.SignerAccount,OPR) then begin
          OPR.NOpInsideBlock := i;
          OPR.Balance := -1;
        end else OPR := CT_TOperationResume_NUL;
        FillOperationResumeToJSONObject(OPR,Obj);
      end;
      Result := true;
    Finally
      OperationsHashTree.Free;
    End;
  End;

  Function ExecuteOperations(Const HexaStringOperationsHashTree : String) : Boolean;
  var OperationsHashTree : TOperationsHashTree;
    errors : String;
    i : Integer;
    OperationsResumeList : TOperationsResumeList;
  Begin
    Result := False;
    if Not TPascalCoinJSONComp.HexaStringToOperationsHashTree(HexaStringOperationsHashTree,CT_BUILD_PROTOCOL,OperationsHashTree,errors) then begin
      ErrorNum:=CT_RPC_ErrNum_InvalidData;
      ErrorDesc:= 'Error decoding param "rawoperations": '+errors;
      Exit;
    end;
    Try
      errors := '';
      OperationsResumeList := TOperationsResumeList.Create;
      Try
        i := FNode.AddOperations(Nil,OperationsHashTree,OperationsResumeList,errors);
        if (i<0) then begin
          ErrorNum:=CT_RPC_ErrNum_InternalError;
          ErrorDesc:=errors;
          exit;
        end;
        GetResultArray.Clear; // Inits an array
        for i := 0 to OperationsResumeList.Count - 1 do begin
          FillOperationResumeToJSONObject(OperationsResumeList[i],GetResultArray.GetAsObject(i));
        end;
      Finally
        OperationsResumeList.Free;
      End;
      Result := true;
    Finally
      OperationsHashTree.Free;
    End;
  End;

  Function DoEncrypt(RawPayload : TRawBytes; pub_key : TAccountKey; Const Payload_method, EncodePwdForAES : String) : Boolean;
  Var f_raw : TRawBytes;
  begin
    Result := false;
    if (length(RawPayload)>0) then begin
      if (Payload_method='none') then f_raw:=RawPayload
      else if (Payload_method='pubkey') then begin
        TPCEncryption.DoPascalCoinECIESEncrypt(pub_key,RawPayload,f_raw);
      end else if (Payload_method='aes') then begin
        f_raw := TPCEncryption.DoPascalCoinAESEncrypt(RawPayload,TEncoding.ANSI.GetBytes(EncodePwdForAES));
      end else begin
        ErrorNum:=CT_RPC_ErrNum_InvalidOperation;
        ErrorDesc:='Invalid encode payload method: '+Payload_method;
        exit;
      end;
    end else f_raw := Nil;
    jsonresponse.GetAsVariant('result').Value := TCrypto.ToHexaString(f_raw);
    Result := true;
  end;

  Function DoDecrypt(RawEncryptedPayload : TRawBytes; jsonArrayPwds : TPCJSONArray) : Boolean;
  var i : Integer;
    pkey : TECPrivateKey;
    decrypted_payload : TRawBytes;
  Begin
    Result := false;
    if Length(RawEncryptedPayload)=0 then begin
      GetResultObject.GetAsVariant('result').Value:= False;
      GetResultObject.GetAsVariant('enc_payload').Value:= '';
      Result := true;
      exit;
    end;
    for i := 0 to _RPCServer.WalletKeys.Count - 1 do begin
      pkey := _RPCServer.WalletKeys.Key[i].PrivateKey;
      if (assigned(pkey)) then begin
        if TPCEncryption.DoPascalCoinECIESDecrypt(pkey.PrivateKey,RawEncryptedPayload,decrypted_payload) then begin
          GetResultObject.GetAsVariant('result').Value:= true;
          GetResultObject.GetAsVariant('enc_payload').Value:= TCrypto.ToHexaString(RawEncryptedPayload);
          GetResultObject.GetAsVariant('unenc_payload').Value:= decrypted_payload.ToPrintable;
          GetResultObject.GetAsVariant('unenc_hexpayload').Value:= TCrypto.ToHexaString(decrypted_payload);
          GetResultObject.GetAsVariant('payload_method').Value:= 'key';
          GetResultObject.GetAsVariant('enc_pubkey').Value:= TCrypto.ToHexaString(TAccountComp.AccountKey2RawString(pkey.PublicKey));
          Result := true;
          Exit;
        end;
      end;
    end;
    for i := 0 to jsonArrayPwds.Count - 1 do begin
      if TPCEncryption.DoPascalCoinAESDecrypt(RawEncryptedPayload,TEncoding.ANSI.GetBytes(jsonArrayPwds.GetAsVariant(i).AsString('')),decrypted_payload) then begin
        GetResultObject.GetAsVariant('result').Value:= true;
        GetResultObject.GetAsVariant('enc_payload').Value:= TCrypto.ToHexaString(RawEncryptedPayload);
        GetResultObject.GetAsVariant('unenc_payload').Value:= decrypted_payload.ToPrintable;
        GetResultObject.GetAsVariant('unenc_hexpayload').Value:= TCrypto.ToHexaString(decrypted_payload);
        GetResultObject.GetAsVariant('payload_method').Value:= 'pwd';
        GetResultObject.GetAsVariant('pwd').Value:= jsonArrayPwds.GetAsVariant(i).AsString('');
        Result := true;
        exit;
      end;
    end;
    // Not found
    GetResultObject.GetAsVariant('result').Value:= False;
    GetResultObject.GetAsVariant('enc_payload').Value:= TCrypto.ToHexaString(RawEncryptedPayload);
    Result := true;
  End;

  Function CapturePubKey(const prefix : String; var pubkey : TAccountKey; var errortxt : String) : Boolean;
  begin
    Result := TPascalCoinJSONComp.CapturePubKey(params,prefix,pubkey,errortxt);
  end;

  function SignListAccountForSaleEx(params : TPCJSONObject; OperationsHashTree : TOperationsHashTree; current_protocol : Word; const actualAccounKey : TAccountKey; last_n_operation : Cardinal) : boolean;
    // params:
    // "type" (optional) is the type of listing to perform "public_sale", "private_sale", "atomic_account_swap", "atomic_coin_swap"
    // "account_signer" is the account that signs operations and pays the fee
    // "account_target" is the account being listed
    // "locked_until_block" is until which block will be locked this account (Note: A locked account cannot change it's state until sold or finished lock)
    // "price" is the price
    // "seller_account" is the account to pay (seller account)
    // "new_b58_pubkey" or "new_enc_pubkey" is the future public key for this sale (private sale), otherwise is open and everybody can buy
    // "enc_hash_lock" (optional) hex-encoded hash-lock for an atomic swap
  var
    opSale: TOpListAccountForSaleOrSwap;
    LListType : TAccountState;
    account_signer, account_target, seller_account : Cardinal;
    locked_until_block : Cardinal;
    price,fee : Int64;
    LNew_pubkey : TAccountKey;
    LHasHashLock, LHasNewPubkey : Boolean;
    LHashLock32 : T32Bytes;
    LHashLockRaw : TRawBytes;
    LStrVal : String;
  begin
    Result := false;
    if not CaptureAccountNumber('account_signer',False,account_signer,ErrorDesc) then begin
      ErrorNum := CT_RPC_ErrNum_InvalidAccount;
      Exit;
    end;
    if not CaptureAccountNumber('account_target',False,account_target,ErrorDesc) then begin
      ErrorNum := CT_RPC_ErrNum_InvalidAccount;
      Exit;
    end;
    if not CaptureAccountNumber('seller_account',False,seller_account,ErrorDesc) then begin
      ErrorNum := CT_RPC_ErrNum_InvalidAccount;
      Exit;
    end;
    locked_until_block := params.AsInteger('locked_until_block',MaxInt);
    if (locked_until_block>=MaxInt) then begin
      ErrorNum := CT_RPC_ErrNum_InvalidData;
      ErrorDesc := 'Invalid "locked_until_block" value';
      Exit;
    end;
    price := ToPascalCoins(params.AsDouble('price',0));
    if (price=0) then begin
      ErrorNum := CT_RPC_ErrNum_InvalidData;
      ErrorDesc := 'Invalid price value';
      Exit;
    end;
    fee := ToPascalCoins(params.AsDouble('fee',0));
    if (fee<0) then begin
      ErrorNum := CT_RPC_ErrNum_InvalidData;
      ErrorDesc := 'Invalid fee value';
      Exit;
    end;
    if (params.IndexOfName('new_b58_pubkey')>=0) or (params.IndexOfName('new_enc_pubkey')>=0) then begin
      If Not CapturePubKey('new_',LNew_pubkey,ErrorDesc) then begin
        ErrorNum := CT_RPC_ErrNum_InvalidPubKey;
        Exit;
      end;
      LHasNewPubkey := True;
    end else begin
      LHasNewPubkey := False;
      LNew_pubkey := CT_TECDSA_Public_Nul;
    end;

    LHasHashLock := False;
    LHashLock32 := CT_HashLock_NUL;
    if (params.IndexOfName('enc_hash_lock') >= 0) then begin
      LStrVal := params.AsString('enc_hash_lock', '');
      if TCrypto.HexaToRaw(LStrVal,LHashLockRaw) then begin
        if Length(LHashLockRaw)=32 then begin
          LHasHashLock := True;
          LHashLock32 := TBaseType.To32Bytes( LHashLockRaw );
        end;
      end;
      if Not LHasHashLock then begin
        ErrorNum := CT_RPC_ErrNum_InvalidData;
        ErrorDesc := 'Invalid "enc_hash_lock" value. Must be 32 byte hexadecimal string.';
        Exit;
      end;
    end;

    if params.IndexOfName('type') >= 0 then begin
      LStrVal := params.AsString('type', '');
      if (LStrVal = 'public_sale') then begin
        LListType := as_ForSale;
        if LHasNewPubkey then begin
          ErrorNum := CT_RPC_ErrNum_InvalidData;
          ErrorDesc := 'public_sale type must not contain new public key param';
          Exit;
        end;
      end else if (LStrVal = 'private_sale') then begin
        LListType := as_ForSale;
        if Not LHasNewPubkey then begin
          ErrorNum := CT_RPC_ErrNum_InvalidData;
          ErrorDesc := 'private_sale type must contain new public key param';
          Exit;
        end;
      end else if (LStrVal = 'atomic_account_swap') then
        LListType := as_ForAtomicAccountSwap
      else if (LStrVal = 'atomic_coin_swap') then
        LListType := as_ForAtomicCoinSwap
      else begin
        ErrorNum := CT_RPC_ErrNum_InvalidData;
        ErrorDesc := 'Invalid "type" value provided: "'+LStrVal+'"';
        Exit;
      end;
      if (LListType in [as_ForAtomicAccountSwap, as_ForAtomicCoinSwap]) and (NOT LHasHashLock) then begin
        ErrorNum := CT_RPC_ErrNum_InvalidData;
        ErrorDesc := 'Missing "enc_hash_lock" param. Required for atomic swaps';
        Exit;
      end;
    end else begin
      // type not specified, implied private or public sale, based on provided new publick key or not
      LListType := as_ForSale;
    end;

    opSale := CreateOperationListAccountForSale(current_protocol, LListType, account_signer,last_n_operation,account_target,actualAccounKey,price,locked_until_block,
      seller_account, LNew_pubkey,fee, LHashLock32,
      TCrypto.HexaToRaw(params.AsString('payload','')),
      params.AsString('payload_method','dest'),params.AsString('pwd',''));
    if opSale=nil then exit;
    try
      OperationsHashTree.AddOperationToHashTree(opSale);
      Result := true;
    finally
      opSale.Free;
    end;
  end;

  function SignListAccountForSaleColdWallet(Const HexaStringOperationsHashTree : String) : boolean;
  var errors : String;
    OperationsHashTree : TOperationsHashTree;
    accountpubkey : TAccountKey;
    last_n_operation : Cardinal;
    current_protocol : Word;
  begin
    current_protocol := params.AsCardinal('protocol',CT_BUILD_PROTOCOL);
    Result := false;
    if Not TPascalCoinJSONComp.HexaStringToOperationsHashTree(HexaStringOperationsHashTree,current_protocol,OperationsHashTree,errors) then begin
      ErrorNum:=CT_RPC_ErrNum_InvalidData;
      ErrorDesc:= 'Error decoding param previous operations hash tree raw value: '+errors;
      Exit;
    end;
    try
      If Not CapturePubKey('signer_',accountpubkey,ErrorDesc) then begin
        ErrorNum := CT_RPC_ErrNum_InvalidPubKey;
        ErrorDesc := 'Params "signer_b58_pubkey" or "signer_enc_pubkey" not found';
        exit;
      end;
      last_n_operation := params.AsCardinal('last_n_operation',0);
      If not SignListAccountForSaleEx(params,OperationsHashTree,current_protocol, accountpubkey,last_n_operation) then Exit
      else Result := True;
      TPascalCoinJSONComp.FillOperationsHashTreeObject(OperationsHashTree,GetResultObject);
    finally
      OperationsHashTree.Free;
    end;
  end;

  function SignDelistAccountForSaleEx(params : TPCJSONObject; OperationsHashTree : TOperationsHashTree; current_protocol : Word; const actualAccountKey : TAccountKey; last_n_operation : Cardinal) : boolean;
    // params:
    // "account_signer" is the account that signs operations and pays the fee
    // "account_target" is the delisted account
    // "locked_until_block" is until which block will be locked this account (Note: A locked account cannot change it's state until sold or finished lock)
    // "price" is the price
    // "seller_account" is the account to pay
    // "new_b58_pubkey" or "new_enc_pubkey" is the future public key for this sale (private sale), otherwise is open and everybody can buy
  var
    opDelist: TOpDelistAccountForSale;
    account_signer, account_target : Cardinal;
    fee : Int64;
  begin
    Result := false;
    if not CaptureAccountNumber('account_signer',False,account_signer,ErrorDesc) then begin
      ErrorNum := CT_RPC_ErrNum_InvalidAccount;
      Exit;
    end;
    if not CaptureAccountNumber('account_target',False,account_target,ErrorDesc) then begin
      ErrorNum := CT_RPC_ErrNum_InvalidAccount;
      Exit;
    end;
    fee := ToPascalCoins(params.AsDouble('fee',0));
    if (fee<0) then begin
      ErrorNum := CT_RPC_ErrNum_InvalidData;
      ErrorDesc := 'Invalid fee value';
      Exit;
    end;
    opDelist := CreateOperationDelistAccountForSale(current_protocol,account_signer,last_n_operation,account_target,actualAccountKey,fee,TCrypto.HexaToRaw(params.AsString('payload','')),
      params.AsString('payload_method','dest'),params.AsString('pwd',''));
    if opDelist=nil then exit;
    try
      OperationsHashTree.AddOperationToHashTree(opDelist);
      Result := true;
    finally
      opDelist.Free;
    end;
  end;

  // This function creates a TOpChangeAccountInfo without looking for actual state (cold wallet)
  // It assumes that account_number,account_last_n_operation and account_pubkey are correct
  Function CreateOperationChangeAccountInfo(current_protocol : Word; account_signer, account_last_n_operation, account_target: Cardinal; const account_signer_pubkey: TAccountKey;
    changePubKey : Boolean; Const new_account_pubkey : TAccountKey;
    changeName: Boolean; Const new_name : TRawBytes;
    changeType: Boolean; new_type : Word;
    AChangeAccountData : Boolean; ANew_AccountData : TRawBytes;
    fee : UInt64; RawPayload : TRawBytes; Const Payload_method, EncodePwd : String) : TOpChangeAccountInfo;
  // "payload_method" types: "none","dest"(default),"sender","aes"(must provide "pwd" param)
  var privateKey : TECPrivateKey;
    errors : String;
    LOpPayload : TOperationPayload;
    aux_target_pubkey : TAccountKey;
  Begin
    Result := Nil;
    if Not RPCServer.CheckAndGetPrivateKeyInWallet(account_signer_pubkey,privateKey,ErrorNum,ErrorDesc) then Exit(Nil);
    if (Payload_method='dest') And (new_account_pubkey.EC_OpenSSL_NID<>CT_TECDSA_Public_Nul.EC_OpenSSL_NID) then begin
        // If using 'dest', only will apply if there is a fixed new public key, otherwise will use current public key of account
       aux_target_pubkey := new_account_pubkey;
    end else aux_target_pubkey := account_signer_pubkey;
    if Not TPascalCoinJSONComp.CheckAndGetEncodedRAWPayload(RawPayload,Payload_method,EncodePwd,account_signer_pubkey,aux_target_pubkey,LOpPayload,ErrorNum,ErrorDesc) then Exit(Nil);
    Result := TOpChangeAccountInfo.CreateChangeAccountInfo(current_protocol,
      account_signer,account_last_n_operation+1,account_target,
      privateKey,
      changePubKey,new_account_pubkey,changeName,new_name,changeType,new_type,
      AChangeAccountData,ANew_AccountData,
      fee,LOpPayload);
    if Not Result.HasValidSignature then begin
      FreeAndNil(Result);
      ErrorNum:=CT_RPC_ErrNum_InternalError;
      ErrorDesc:='Invalid signature';
      exit;
    end;
  End;

  function SignChangeAccountInfoEx(params : TPCJSONObject; OperationsHashTree : TOperationsHashTree; current_protocol : Word; const actualAccountKey : TAccountKey; last_n_operation : Cardinal) : boolean;
    // params:
    // "account_signer" is the account that signs operations and pays the fee
    // "account_target" is the target to change info
    // "new_b58_pubkey" or "new_enc_pubkey" is the new public key for this account
    // "new_name" is the new account name
    // "new_type" is the new account type
  var
    opChangeInfo: TOpChangeAccountInfo;
    account_signer, account_target : Cardinal;
    fee : Int64;
    changeKey,changeName,changeType,changeAccountData : Boolean;
    new_name : TRawBytes;
    new_type : Word;
    new_typeI : Integer;
    new_pubkey : TAccountKey;
    new_AccountData : TRawBytes;
  begin
    Result := false;
    if not CaptureAccountNumber('account_signer',False,account_signer,ErrorDesc) then begin
      ErrorNum := CT_RPC_ErrNum_InvalidAccount;
      Exit;
    end;
    if not CaptureAccountNumber('account_target',False,account_target,ErrorDesc) then begin
      ErrorNum := CT_RPC_ErrNum_InvalidAccount;
      Exit;
    end;
    fee := ToPascalCoins(params.AsDouble('fee',0));
    if (fee<0) then begin
      ErrorNum := CT_RPC_ErrNum_InvalidData;
      ErrorDesc := 'Invalid fee value';
      Exit;
    end;
    if (params.IndexOfName('new_b58_pubkey')>=0) or (params.IndexOfName('new_enc_pubkey')>=0) then begin
      changeKey:=True;
      If Not CapturePubKey('new_',new_pubkey,ErrorDesc) then begin
        ErrorNum := CT_RPC_ErrNum_InvalidPubKey;
        Exit;
      end;
    end else begin
      new_pubkey := CT_TECDSA_Public_Nul;
      changeKey:=False;
    end;
    if (params.IndexOfName('new_name')>=0) then begin
      changeName:=True;
      new_name.FromString(params.AsString('new_name',''));
    end else begin
      new_name := Nil;
      changeName:=False;
    end;
    if (params.IndexOfName('new_type')>=0) then begin
      changeType:=True;
      new_typeI := params.AsInteger('new_type',-1);
      if (new_typeI<0) Or (new_typeI>65536) then begin
        ErrorNum := CT_RPC_ErrNum_InvalidData;
        ErrorDesc := 'Invalid new type value '+IntToStr(new_typeI);
        Exit;
      end;
      new_type := new_typeI;
    end else begin
      new_type := 0;
      changeType:=False;
    end;

    if (params.IndexOfName('new_data')>=0) then begin
      changeAccountData:=True;
      if not TCrypto.HexaToRaw(params.AsString('new_data',''),new_AccountData) then begin
        ErrorNum := CT_RPC_ErrNum_InvalidData;
        ErrorDesc := 'new_data is not an HEXASTRING';
        Exit;
      end;
      if Length(new_AccountData)>CT_MaxAccountDataSize then begin
        ErrorNum := CT_RPC_ErrNum_InvalidData;
        ErrorDesc := 'new_data limited to 0..'+IntToStr(CT_MaxAccountDataSize)+' bytes';
        Exit;
      end;
    end else begin
      new_AccountData := Nil;
      changeAccountData:=False;
    end;

    opChangeInfo := CreateOperationChangeAccountInfo(current_protocol,account_signer,last_n_operation,account_target,actualAccountKey,
      changeKey,new_pubkey,
      changeName,new_name,
      changeType,new_type,
      changeAccountData,new_AccountData,
      fee,TCrypto.HexaToRaw(params.AsString('payload','')),
      params.AsString('payload_method','dest'),params.AsString('pwd',''));
    if opChangeInfo=nil then exit;
    try
      OperationsHashTree.AddOperationToHashTree(opChangeInfo);
      Result := true;
    finally
      opChangeInfo.Free;
    end;
  end;

  function SignChangeAccountInfoColdWallet(Const HexaStringOperationsHashTree : String) : boolean;
  var errors : String;
    OperationsHashTree : TOperationsHashTree;
    accountpubkey : TAccountKey;
    last_n_operation : Cardinal;
    current_protocol : Word;
  begin
    Result := false;
    current_protocol := params.AsCardinal('protocol',CT_BUILD_PROTOCOL);
    if Not TPascalCoinJSONComp.HexaStringToOperationsHashTree(HexaStringOperationsHashTree,current_protocol,OperationsHashTree,errors) then begin
      ErrorNum:=CT_RPC_ErrNum_InvalidData;
      ErrorDesc:= 'Error decoding param previous operations hash tree raw value: '+errors;
      Exit;
    end;
    try
      If Not CapturePubKey('signer_',accountpubkey,ErrorDesc) then begin
        ErrorNum := CT_RPC_ErrNum_InvalidPubKey;
        ErrorDesc := 'Params "signer_b58_pubkey" or "signer_enc_pubkey" not found';
        exit;
      end;
      last_n_operation := params.AsCardinal('last_n_operation',0);
      If not SignChangeAccountInfoEx(params,OperationsHashTree,current_protocol,accountpubkey,last_n_operation) then Exit
      else Result := True;
      TPascalCoinJSONComp.FillOperationsHashTreeObject(OperationsHashTree,GetResultObject);
    finally
      OperationsHashTree.Free;
    end;
  end;

  function SignDelistAccountForSaleColdWallet(Const HexaStringOperationsHashTree : String) : boolean;
  var errors : String;
    OperationsHashTree : TOperationsHashTree;
    accountpubkey : TAccountKey;
    last_n_operation : Cardinal;
    current_protocol : Word;
  begin
    current_protocol := params.AsCardinal('protocol',CT_BUILD_PROTOCOL);
    Result := false;
    if Not TPascalCoinJSONComp.HexaStringToOperationsHashTree(HexaStringOperationsHashTree,current_protocol,OperationsHashTree,errors) then begin
      ErrorNum:=CT_RPC_ErrNum_InvalidData;
      ErrorDesc:= 'Error decoding param previous operations hash tree raw value: '+errors;
      Exit;
    end;
    try
      If Not CapturePubKey('signer_',accountpubkey,ErrorDesc) then begin
        ErrorNum := CT_RPC_ErrNum_InvalidPubKey;
        ErrorDesc := 'Params "signer_b58_pubkey" or "signer_enc_pubkey" not found';
        exit;
      end;
      last_n_operation := params.AsCardinal('last_n_operation',0);
      If not SignDelistAccountForSaleEx(params,OperationsHashTree,current_protocol,accountpubkey,last_n_operation) then Exit
      else Result := True;
      TPascalCoinJSONComp.FillOperationsHashTreeObject(OperationsHashTree,GetResultObject);
    finally
      OperationsHashTree.Free;
    end;
  end;

  function SignBuyAccountEx(params : TPCJSONObject; OperationsHashTree : TOperationsHashTree; current_protocol : Word; const buyerAccountKey : TAccountKey; last_n_operation : Cardinal) : boolean;
    // params:
    // "buyer_account" is the buyer account
    // "account_to_purchase" is the account to purchase
    // "price" is the price
    // "seller_account" is the account to pay
    // "new_b58_pubkey" or "new_enc_pubkey" is the future public key for this sale (private sale), otherwise is open and everybody can buy
    // "amount" is the transferred amount to pay (can exceed price)
  var
    opBuy: TOpBuyAccount;
    buyer_account, account_to_purchase, seller_account : Cardinal;
    price,amount,fee : Int64;
    new_pubkey : TAccountKey;
  begin
    Result := false;
    if not CaptureAccountNumber('buyer_account',False,buyer_account,ErrorDesc) then begin
      ErrorNum := CT_RPC_ErrNum_InvalidAccount;
      Exit;
    end;
    if not CaptureAccountNumber('account_to_purchase',False,account_to_purchase,ErrorDesc) then begin
      ErrorNum := CT_RPC_ErrNum_InvalidAccount;
      Exit;
    end;
    if not CaptureAccountNumber('seller_account',False,seller_account,ErrorDesc) then begin
      ErrorNum := CT_RPC_ErrNum_InvalidAccount;
      Exit;
    end;
    price := ToPascalCoins(params.AsDouble('price',0));
    if (price<0) then begin
      ErrorNum := CT_RPC_ErrNum_InvalidData;
      ErrorDesc := 'Invalid price value';
      Exit;
    end;
    amount := ToPascalCoins(params.AsDouble('amount',0));
    if (amount<0) then begin
      ErrorNum := CT_RPC_ErrNum_InvalidData;
      ErrorDesc := 'Invalid amount value';
      Exit;
    end;
    fee := ToPascalCoins(params.AsDouble('fee',0));
    if (fee<0) then begin
      ErrorNum := CT_RPC_ErrNum_InvalidData;
      ErrorDesc := 'Invalid fee value';
      Exit;
    end;
    if (params.IndexOfName('new_b58_pubkey')>=0) or (params.IndexOfName('new_enc_pubkey')>=0) then begin
      If Not CapturePubKey('new_',new_pubkey,ErrorDesc) then begin
        ErrorNum := CT_RPC_ErrNum_InvalidPubKey;
        Exit;
      end;
    end else new_pubkey := CT_TECDSA_Public_Nul;
    opBuy := CreateOperationBuyAccount(current_protocol,buyer_account,last_n_operation,buyerAccountKey,account_to_purchase,price,amount,seller_account,new_pubkey,fee,
      TCrypto.HexaToRaw(params.AsString('payload','')),
      params.AsString('payload_method','dest'),params.AsString('pwd',''));
    if opBuy=nil then exit;
    try
      OperationsHashTree.AddOperationToHashTree(opBuy);
      Result := true;
    finally
      opBuy.Free;
    end;
  end;

  function SignBuyAccountColdWallet(Const HexaStringOperationsHashTree : String) : boolean;
  var errors : String;
    OperationsHashTree : TOperationsHashTree;
    accountpubkey : TAccountKey;
    last_n_operation : Cardinal;
    current_protocol : Word;
  begin
    current_protocol := params.AsCardinal('protocol',CT_BUILD_PROTOCOL);
    Result := false;
    if Not TPascalCoinJSONComp.HexaStringToOperationsHashTree(HexaStringOperationsHashTree,current_protocol,OperationsHashTree,errors) then begin
      ErrorNum:=CT_RPC_ErrNum_InvalidData;
      ErrorDesc:= 'Error decoding param previous operations hash tree raw value: '+errors;
      Exit;
    end;
    try
      If Not CapturePubKey('signer_',accountpubkey,ErrorDesc) then begin
        ErrorNum := CT_RPC_ErrNum_InvalidPubKey;
        ErrorDesc := 'Params "signer_b58_pubkey" or "signer_enc_pubkey" not found';
        exit;
      end;
      last_n_operation := params.AsCardinal('last_n_operation',0);
      If not SignBuyAccountEx(params,OperationsHashTree,current_protocol,accountpubkey,last_n_operation) then Exit
      else Result := True;
      TPascalCoinJSONComp.FillOperationsHashTreeObject(OperationsHashTree,GetResultObject);
    finally
      OperationsHashTree.Free;
    end;
  end;

  function ListAccountForSale : boolean;
  Var OperationsHashTree : TOperationsHashTree;
    account_signer, account_target : TAccount;
    opt : TPCOperation;
    opr : TOperationResume;
    errors : String;
    c_account : Cardinal;
  Begin
    FNode.OperationSequenceLock.Acquire;  // Use lock to prevent N_Operation race-condition on concurrent invocations
    try
      Result := False;
      OperationsHashTree := TOperationsHashTree.Create;
      try
        if not CaptureAccountNumber('account_signer',True,c_account,ErrorDesc) then begin
          ErrorNum := CT_RPC_ErrNum_InvalidAccount;
          Exit;
        end;
        account_signer := FNode.GetMempoolAccount(c_account);
        if not CaptureAccountNumber('account_target',True,c_account,ErrorDesc) then begin
          ErrorNum := CT_RPC_ErrNum_InvalidAccount;
          Exit;
        end;
        account_target := FNode.GetMempoolAccount(c_account);
        if (Not TAccountComp.EqualAccountKeys(account_signer.accountInfo.accountKey,account_target.accountInfo.accountKey)) then begin
          ErrorNum := CT_RPC_ErrNum_InvalidAccount;
          ErrorDesc := 'account_signer and account_target have distinct keys. Cannot sign';
          Exit;
        end;
        If not SignListAccountForSaleEx(params,OperationsHashTree,FNode.Bank.SafeBox.CurrentProtocol, account_signer.accountInfo.accountKey,account_signer.n_operation) then Exit;
        opt := OperationsHashTree.GetOperation(0);
        If not FNode.AddOperation(Nil,opt,errors) then begin
          ErrorNum := CT_RPC_ErrNum_InternalError;
          ErrorDesc := errors;
          Exit;
        end else Result := True;
        TPCOperation.OperationToOperationResume(0,opt,False,c_account,opr);
        FillOperationResumeToJSONObject(opr,GetResultObject);
      finally
        OperationsHashTree.Free;
      end;
    finally
      FNode.OperationSequenceLock.Release;
    end;
  End;

  function DelistAccountForSale(params : TPCJSONObject) : boolean;
  Var OperationsHashTree : TOperationsHashTree;
    account_signer, account_target : TAccount;
    opt : TPCOperation;
    opr : TOperationResume;
    errors : String;
    c_account : Cardinal;
  Begin
    FNode.OperationSequenceLock.Acquire;  // Use lock to prevent N_Operation race-condition on concurrent invocations
    try
      Result := False;
      OperationsHashTree := TOperationsHashTree.Create;
      try
        if not CaptureAccountNumber('account_signer',True,c_account,ErrorDesc) then begin
          ErrorNum := CT_RPC_ErrNum_InvalidAccount;
          Exit;
        end;
        account_signer := FNode.GetMempoolAccount(c_account);
        if not CaptureAccountNumber('account_target',True,c_account,ErrorDesc) then begin
          ErrorNum := CT_RPC_ErrNum_InvalidAccount;
          Exit;
        end;
        account_target := FNode.GetMempoolAccount(c_account);
        if (Not TAccountComp.EqualAccountKeys(account_signer.accountInfo.accountKey,account_target.accountInfo.accountKey)) then begin
          ErrorNum := CT_RPC_ErrNum_InvalidAccount;
          ErrorDesc := 'account_signer and account_target have distinct keys. Cannot sign';
          Exit;
        end;
        If not SignDelistAccountForSaleEx(params,OperationsHashTree,FNode.Bank.SafeBox.CurrentProtocol,account_signer.accountInfo.accountKey,account_signer.n_operation) then Exit;
        opt := OperationsHashTree.GetOperation(0);
        If not FNode.AddOperation(Nil,opt,errors) then begin
          ErrorNum := CT_RPC_ErrNum_InternalError;
          ErrorDesc := errors;
          Exit;
        end else Result := True;
        TPCOperation.OperationToOperationResume(0,opt,False,c_account,opr);
        FillOperationResumeToJSONObject(opr,GetResultObject);
      finally
        OperationsHashTree.Free;
      end;
    finally
      FNode.OperationSequenceLock.Acquire;
    end;
  End;

  function BuyAccount : boolean;
  Var OperationsHashTree : TOperationsHashTree;
    buyer_account, account_to_purchase : TAccount;
    opt : TPCOperation;
    opr : TOperationResume;
    errors : String;
    c_account : Cardinal;
  Begin
    FNode.OperationSequenceLock.Acquire;  // Use lock to prevent N_Operation race-condition on concurrent invocations
    try
      Result := False;
      OperationsHashTree := TOperationsHashTree.Create;
      try
        if not CaptureAccountNumber('buyer_account',True,c_account,ErrorDesc) then begin
          ErrorNum := CT_RPC_ErrNum_InvalidAccount;
          Exit;
        end;
        buyer_account := FNode.GetMempoolAccount(c_account);
        // Check params
        if not CaptureAccountNumber('account_to_purchase',True,c_account,ErrorDesc) then begin
          ErrorNum := CT_RPC_ErrNum_InvalidAccount;
          Exit;
        end;
        account_to_purchase := FNode.GetMempoolAccount(c_account);
        if Not TAccountComp.IsAccountForSale(account_to_purchase.accountInfo) then begin
          ErrorNum := CT_RPC_ErrNum_InvalidAccount;
          ErrorDesc := 'Account is not for sale: '+params.AsString('account_to_purchase','');
          Exit;
        end;
        // Fill automatic params
        if (params.IndexOfName('price')<0) then
          params.GetAsVariant('price').Value := ToJSONCurrency( account_to_purchase.accountInfo.price );
        if (params.IndexOfName('seller_account')<0) then
          params.GetAsVariant('seller_account').Value := account_to_purchase.accountInfo.account_to_pay;
        If not SignBuyAccountEx(params,OperationsHashTree,FNode.Bank.SafeBox.CurrentProtocol,buyer_account.accountInfo.accountKey,buyer_account.n_operation) then Exit;
        opt := OperationsHashTree.GetOperation(0);
        If not FNode.AddOperation(Nil,opt,errors) then begin
          ErrorNum := CT_RPC_ErrNum_InternalError;
          ErrorDesc := errors;
          Exit;
        end else Result := True;
        TPCOperation.OperationToOperationResume(0,opt,False,c_account,opr);
        FillOperationResumeToJSONObject(opr,GetResultObject);
      finally
        OperationsHashTree.Free;
      end;
    finally
      FNode.OperationSequenceLock.Release;
    end;
  End;

  function ChangeAccountInfo : boolean;
  Var OperationsHashTree : TOperationsHashTree;
    account_signer, account_target : TAccount;
    opt : TPCOperation;
    opr : TOperationResume;
    errors : String;
    c_account : Cardinal;
  Begin
    FNode.OperationSequenceLock.Acquire;  // Use lock to prevent N_Operation race-condition on concurrent invocations
    try
      Result := False;
      OperationsHashTree := TOperationsHashTree.Create;
      try
        if not CaptureAccountNumber('account_signer',True,c_account,ErrorDesc) then begin
          ErrorNum := CT_RPC_ErrNum_InvalidAccount;
          Exit;
        end;
        account_signer := FNode.GetMempoolAccount(c_account);
        if not CaptureAccountNumber('account_target',True,c_account,ErrorDesc) then begin
          ErrorNum := CT_RPC_ErrNum_InvalidAccount;
          Exit;
        end;
        account_target := FNode.GetMempoolAccount(c_account);
        if (Not TAccountComp.EqualAccountKeys(account_signer.accountInfo.accountKey,account_target.accountInfo.accountKey)) then begin
          ErrorNum := CT_RPC_ErrNum_InvalidAccount;
          ErrorDesc := 'account_signer and account_target have distinct keys. Cannot sign';
          Exit;
        end;
        If not SignChangeAccountInfoEx(params,OperationsHashTree,FNode.Bank.SafeBox.CurrentProtocol,account_signer.accountInfo.accountKey,account_signer.n_operation) then Exit;
        opt := OperationsHashTree.GetOperation(0);
        If not FNode.AddOperation(Nil,opt,errors) then begin
          ErrorNum := CT_RPC_ErrNum_InternalError;
          ErrorDesc := errors;
          Exit;
        end else Result := True;
        TPCOperation.OperationToOperationResume(0,opt,False,c_account,opr);
        FillOperationResumeToJSONObject(opr,GetResultObject);
      finally
        OperationsHashTree.Free;
      end;
    finally
      FNode.OperationSequenceLock.Release;
    end;
  End;

  function FindNOperations : Boolean;
  Var oprl : TOperationsResumeList;
    start_block, account, n_operation_min, n_operation_max : Cardinal;
    sor : TSearchOperationResult;
    jsonarr : TPCJSONArray;
    i : Integer;
  begin
    Result := False;
    oprl := TOperationsResumeList.Create;
    try
      if not CaptureAccountNumber('account',True,account,ErrorDesc) then begin
        ErrorNum:=CT_RPC_ErrNum_InvalidAccount;
        exit;
      end;
      If (params.IndexOfName('n_operation_min')<0) Or (params.IndexOfName('n_operation_max')<0) then begin
        ErrorNum:=CT_RPC_ErrNum_NotFound;
        ErrorDesc:='Need n_operation_min and n_operation_max params';
        exit;
      end;
      n_operation_min := params.AsCardinal('n_operation_min',0);
      n_operation_max := params.AsCardinal('n_operation_max',0);
      start_block := params.AsCardinal('start_block',0); // Optional: 0 = Search all
      sor := FNode.FindNOperations(account,start_block,true,n_operation_min,n_operation_max,oprl);
      Case sor of
        found : Result := True;
        invalid_params : begin
            ErrorNum:=CT_RPC_ErrNum_NotFound;
            ErrorDesc:='Not found using block/account/n_operation';
            exit;
          end;
        blockchain_block_not_found : begin
            ErrorNum := CT_RPC_ErrNum_InvalidBlock;
            ErrorDesc:='Blockchain file does not contain all blocks to find';
            exit;
          end;
      else Raise Exception.Create('ERROR DEV 20171120-7');
      end;
      jsonarr := jsonresponse.GetAsArray('result');
      if oprl.Count>0 then begin;
        for i:=0 to oprl.Count-1 do begin
          FillOperationResumeToJSONObject(oprl.OperationResume[i],jsonarr.GetAsObject(jsonarr.Count));
        end;
      end;
    finally
      oprl.Free;
    end;
  end;

  function MultiOperationAddOperation(Const HexaStringOperationsHashTree : String) : boolean;
    Function Capture_Current_Account(const nAccount : Int64) : TAccount;
    Begin
      Result := CT_Account_NUL;
      if (nAccount<0) Or (nAccount>=FNode.Bank.AccountsCount) then Exit;
      Result := FNode.GetMempoolAccount( nAccount );
    end;

  var errors : String;
    OperationsHashTree : TOperationsHashTree;
    jsonArr : TPCJSONArray;
    i : Integer;
    sender : TMultiOpSender;
    receiver : TMultiOpReceiver;
    changeinfo : TMultiOpChangeInfo;
    mop : TOpMultiOperation;
  begin
    { This will ADD or UPDATE a MultiOperation with NEW field/s
      - UPDATE: If LAST operation in HexaStringOperationsHashTree RAW value contains a MultiOperation
      - ADD: Otherwise

      NOTE: This function will not check if provided info is valid (enough balance, valid n_operation...), and can work for COLD STORAGE
      - "senders" : ARRAY of OBJECT
        - "account" :
        - "n_operation" : New n_operation value for account (remember, current + 1)
        - "amount" : PASCURRENCY
        - "payload" : HEXASTRING (optional)
        - "payload_type" : Integer (optional) based on PIP-0027
      - "receivers" : ARRAY of OBJECT
        - "account"
        - "amount" : PASCURRENCY
        - "payload" : HEXASTRING (optional)
        - "payload_type" : Integer (optional) based on PIP-0027
      - "changesinfo" : ARRAY of OBJECT
        - "account"
        - "n_operation" : New n_operation value for account (remember, current + 1)
        - "new_b58_pubkey" or "new_enc_pubkey" : (optional) The new public key for this account
        - "new_name" : (optional) The new account name
        - "new_type" : (optional) The new account type
        - "new_data" : HEXASTRING (optional) The new account data
        }
    Result := false;
    if Not HexaStringToOperationsHashTreeAndGetMultioperation(
      Self.FNode.Bank.SafeBox.CurrentProtocol, // HS: 2019-07-09: use current protocol since this API used to build new unpublished operations, not historical ones
      HexaStringOperationsHashTree,True,OperationsHashTree,mop,errors) then begin
      ErrorNum:=CT_RPC_ErrNum_InvalidData;
      ErrorDesc:= 'Error decoding param previous operations hash tree raw value: '+errors;
      Exit;
    end;
    Try
      // "senders"
      jsonArr := params.GetAsArray('senders');
      for i:=0 to jsonArr.Count-1 do begin
        sender := CT_TMultiOpSender_NUL;
        if not TAccountComp.AccountTxtNumberToAccountNumber(jsonArr.GetAsObject(i).AsString('account',''),sender.Account) then begin
          ErrorNum := CT_RPC_ErrNum_InvalidData;
          ErrorDesc := 'Field "account" for "senders" array not found at senders['+IntToStr(i)+']';
          Exit;
        end;
        sender.Amount:= ToPascalCoins(jsonArr.GetAsObject(i).AsDouble('amount',0));
        sender.N_Operation:=jsonArr.GetAsObject(i).AsInteger('n_operation',0);
        // Update N_Operation with valid info
        if (sender.N_Operation<=0) then sender.N_Operation:=Capture_Current_Account(sender.Account).n_operation+1;

        sender.Payload.payload_raw:=TCrypto.HexaToRaw(jsonArr.GetAsObject(i).AsString('payload',''));
        sender.Payload.payload_type := jsonArr.GetAsObject(i).AsInteger('payload_type',CT_TOperationPayload_NUL.payload_type );
        if Not mop.AddTxSender(sender) then begin
          ErrorNum := CT_RPC_ErrNum_InvalidData;
          ErrorDesc := 'Cannot add sender '+inttostr(sender.Account)+' duplicated or invalid data';
          Exit;
        end;
      end;
      // "receivers"
      jsonArr := params.GetAsArray('receivers');
      for i:=0 to jsonArr.Count-1 do begin
        receiver := CT_TMultiOpReceiver_NUL;
        if not TAccountComp.AccountTxtNumberToAccountNumber(jsonArr.GetAsObject(i).AsString('account',''),receiver.Account) then begin
          ErrorNum := CT_RPC_ErrNum_InvalidData;
          ErrorDesc := 'Field "account" for "receivers" array not found at receivers['+IntToStr(i)+']';
          Exit;
        end;
        receiver.Amount:= ToPascalCoins(jsonArr.GetAsObject(i).AsDouble('amount',0));
        receiver.Payload.payload_raw:=TCrypto.HexaToRaw(jsonArr.GetAsObject(i).AsString('payload',''));
        receiver.Payload.payload_type := jsonArr.GetAsObject(i).AsInteger('payload_type',CT_TOperationPayload_NUL.payload_type);
        if Not mop.AddTxReceiver(receiver) then begin
          ErrorNum := CT_RPC_ErrNum_InvalidData;
          ErrorDesc := 'Cannot add receiver '+inttostr(receiver.Account)+' invalid data';
          Exit;
        end;
      end;
      // "changesinfo"
      jsonArr := params.GetAsArray('changesinfo');
      for i:=0 to jsonArr.Count-1 do begin
        changeinfo := CT_TMultiOpChangeInfo_NUL;
        if not TAccountComp.AccountTxtNumberToAccountNumber(jsonArr.GetAsObject(i).AsString('account',''),changeinfo.Account) then begin
          ErrorNum := CT_RPC_ErrNum_InvalidData;
          ErrorDesc := 'Field "account" for "changesinfo" array not found at changesinfo['+IntToStr(i)+']';
          Exit;
        end;
        changeinfo.N_Operation:=jsonArr.GetAsObject(i).AsInteger('n_operation',0);
        // Update N_Operation with valid info
        if (changeinfo.N_Operation<=0) then changeinfo.N_Operation:=Capture_Current_Account(changeinfo.Account).n_operation+1;

        if (jsonArr.GetAsObject(i).IndexOfName('new_b58_pubkey')>=0) or (jsonArr.GetAsObject(i).IndexOfName('new_enc_pubkey')>=0) then begin
          changeinfo.Changes_type:=changeinfo.Changes_type + [public_key];
          If Not TPascalCoinJSONComp.CapturePubKey(jsonArr.GetAsObject(i),'new_',changeinfo.New_Accountkey,ErrorDesc) then begin
            ErrorNum := CT_RPC_ErrNum_InvalidPubKey;
            Exit;
          end;
        end;
        if (jsonArr.GetAsObject(i).IndexOfName('new_name')>=0) then begin
          changeinfo.Changes_type:=changeinfo.Changes_type + [account_name];
          changeinfo.New_Name.FromString(jsonArr.GetAsObject(i).AsString('new_name',''));
        end;
        if (jsonArr.GetAsObject(i).IndexOfName('new_type')>=0) then begin
          changeinfo.Changes_type:=changeinfo.Changes_type + [account_type];
          changeinfo.New_Type:=jsonArr.GetAsObject(i).AsInteger('new_type',0);
        end;
        if (jsonArr.GetAsObject(i).IndexOfName('new_data')>=0) then begin
          changeinfo.Changes_type:=changeinfo.Changes_type + [account_data];
          if Not TCrypto.HexaToRaw(jsonArr.GetAsObject(i).AsString('new_data',''),changeinfo.New_Data) then begin
            ErrorNum:=CT_RPC_ErrNum_InvalidData;
            ErrorDesc:='Invalid HEXASTRING value at new_data param';
            Exit;
          end;
        end;
        if (changeinfo.Changes_type = []) then begin
          ErrorNum:=CT_RPC_ErrNum_InvalidData;
          ErrorDesc:='Need change something for account '+inttostr(changeinfo.Account);
          Exit;
        end;
        if Not mop.AddChangeInfo(changeinfo) then begin
          ErrorNum := CT_RPC_ErrNum_InvalidData;
          ErrorDesc := 'Cannot add receiver '+inttostr(receiver.Account)+' duplicated or invalid data';
          Exit;
        end;
      end;
      // Return multioperation object:
      TPascalCoinJSONComp.FillMultiOperationObject(FNode.Bank.SafeBox.CurrentProtocol,mop,GetResultObject);
    finally
      OperationsHashTree.Free;
    end;
    Result := True;
  end;

  function DoSignOrVerifyMessage(params : TPCJSONObject) : boolean;
    { Will sign data or verify a signature
      In params:
        - "digest" : HEXASTRING containing data to sign
        - "b58_pubkey" or "enc_pubkey" : The public key that must sign "digest" data
        - "signature" : (optional) HEXASTRING If provided, will check if "digest" data is signed by "_pubkey" provided
      Out object:
        - "digest" : HEXASTRING containing data
        - "b58_pubkey" or "enc_pubkey" : The public key that have signed
        - "signature" : HEXASTRING with
      If validation is incorrect or errors, will return an error object }
  var digest : TRawBytes;
    pubKey : TAccountKey;
    signature : TECDSA_SIG;
    iKey : Integer;
  begin
    Result := False;
    if Not TCrypto.HexaToRaw( params.AsString('digest',''),digest ) then begin
      ErrorNum := CT_RPC_ErrNum_InvalidData;
      ErrorDesc:= 'Param digest with invalid hexadecimal data';
      Exit;
    end;
    If Not TPascalCoinJSONComp.CapturePubKey(params,'',pubKey,ErrorDesc) then begin
      ErrorNum := CT_RPC_ErrNum_InvalidPubKey;
      Exit;
    end;
    if (params.IndexOfName('signature')>=0) then begin
      // Verify
      If Not TCrypto.DecodeSignature( TCrypto.HexaToRaw(params.AsString('signature','')),signature) then begin
        ErrorNum := CT_RPC_ErrNum_InvalidData;
        ErrorDesc:= 'Param signature with invalid data';
        Exit;
      end;
      //
      If TCrypto.ECDSAVerify(pubKey,digest,signature) then begin
        GetResultObject.GetAsVariant('digest').Value:=TCrypto.ToHexaString(digest);
        GetResultObject.GetAsVariant('enc_pubkey').Value:=TCrypto.ToHexaString(TAccountComp.AccountKey2RawString(pubKey));
        GetResultObject.GetAsVariant('signature').Value:=TCrypto.ToHexaString(TCrypto.EncodeSignature(signature));
        Result := True;
      end else begin
        // Invalid signature
        ErrorNum := CT_RPC_ErrNum_InvalidSignature;
        ErrorDesc := 'Signature does not match';
        Exit;
      end;
    end else begin
      // Sign process
      if (Not (_RPCServer.FWalletKeys.IsValidPassword)) then begin
        // Wallet is password protected
        ErrorDesc := 'Wallet is password protected';
        ErrorNum := CT_RPC_ErrNum_WalletPasswordProtected;
        Exit;
      end;
      iKey := _RPCServer.FWalletKeys.IndexOfAccountKey(pubKey);
      if (iKey<0) then begin
        ErrorDesc:= 'Public Key not found in wallet: '+TAccountComp.AccountPublicKeyExport(pubKey);
        ErrorNum := CT_RPC_ErrNum_InvalidPubKey;
        Exit;
      end;
      if (Not Assigned(_RPCServer.FWalletKeys.Key[iKey].PrivateKey)) then begin
        ErrorDesc:= 'Private key from public Key not found in wallet: '+TAccountComp.AccountPublicKeyExport(pubKey);
        ErrorNum := CT_RPC_ErrNum_InvalidPubKey;
        Exit;
      end;
      signature := TCrypto.ECDSASign( _RPCServer.FWalletKeys.Key[iKey].PrivateKey.PrivateKey ,digest );
      //
      GetResultObject.GetAsVariant('digest').Value:=TCrypto.ToHexaString(digest);
      GetResultObject.GetAsVariant('enc_pubkey').Value:=TCrypto.ToHexaString(TAccountComp.AccountKey2RawString(pubKey));
      GetResultObject.GetAsVariant('signature').Value:=TCrypto.ToHexaString(TCrypto.EncodeSignature(signature));
      Result := True;
    end;
  end;

  procedure InternalMultiOperationSignCold(multiOperation : TOpMultiOperation; current_protocol : Word; accounts_and_keys : TPCJSONArray; var signedAccounts : Integer);
    { Signs a multioperation in a Cold storage, so cannot check if current signatures are valid because public keys of accounts are unknown
      accounts_and_keys is a JSON ARRAY with Objects:
      - "account"
      - "b58_pubkey" or "enc_pubkey" : The public key of the "account"
    }
  var i,iKey : Integer;
    pubKey : TAccountKey;
    nAccount : Cardinal;
    _error_desc : String;
  begin
    signedAccounts := 0;
    if (Not (_RPCServer.FWalletKeys.IsValidPassword)) then Exit;
    for i := 0 to accounts_and_keys.Count-1 do begin
      if TAccountComp.AccountTxtNumberToAccountNumber(accounts_and_keys.GetAsObject(i).AsString('account',''),nAccount) and
        TPascalCoinJSONComp.CapturePubKey(accounts_and_keys.GetAsObject(i),'',pubKey,_error_desc) then begin
        iKey := _RPCServer.FWalletKeys.IndexOfAccountKey(pubKey);
        if (iKey>=0) then begin
          if (Assigned(_RPCServer.FWalletKeys.Key[iKey].PrivateKey)) then begin
            inc(signedAccounts,multiOperation.DoSignMultiOperationSigner(current_protocol, nAccount,_RPCServer.FWalletKeys.Key[iKey].PrivateKey));
          end;
        end;
      end;
    end;
  end;

  function MultiOperationSignCold(Const HexaStringOperationsHashTree : String) : boolean;
  var errors : String;
    senderOperationsHashTree : TOperationsHashTree;
    mop : TOpMultiOperation;
    i,j : Integer;
    protocol : Word;
  begin
    { This will SIGN a MultiOperation on a HexaStringOperationsHashTree in COLD mode (without knowledge of current public keys)
      Must provide param "accounts_and_keys"
      - "accounts_and_keys" is a JSON ARRAY with Objects:
        - "account"
        - "b58_pubkey" or "enc_pubkey" : The public key of the "account"
      Must provide "protocol" version, by default will use current build protocol
      Will Return an OperationsHashTree Object
    }
    Result := false;
    if (Not (_RPCServer.FWalletKeys.IsValidPassword)) then begin
      // Wallet is password protected
      ErrorDesc := 'Wallet is password protected';
      ErrorNum := CT_RPC_ErrNum_WalletPasswordProtected;
      Exit;
    end;
    protocol := params.GetAsVariant('protocol').AsCardinal(CT_BUILD_PROTOCOL);
    if Not HexaStringToOperationsHashTreeAndGetMultioperation(FNode.Bank.SafeBox.CurrentProtocol, HexaStringOperationsHashTree,False,senderOperationsHashTree,mop,errors) then begin
      ErrorNum:=CT_RPC_ErrNum_InvalidData;
      ErrorDesc:= 'Error decoding param previous operations hash tree raw value: '+errors;
      Exit;
    end;
    Try
      InternalMultiOperationSignCold(mop,protocol,params.GetAsArray('accounts_and_keys'),j);
      // Return multioperation object:
      TPascalCoinJSONComp.FillMultiOperationObject(protocol,mop,GetResultObject);
      Result := True;
    finally
      senderOperationsHashTree.Free;
    end;
  end;
  function MultiOperationSignOnline(Const HexaStringOperationsHashTree : String) : boolean;
  var errors : String;
    senderOperationsHashTree : TOperationsHashTree;
    j,iKey,nSignedAccounts : Integer;
    mop : TOpMultiOperation;
    lSigners : TList<Cardinal>;
    nAccount : Integer;
    pubKey : TAccountKey;
  begin
    Result := false;
    if (Not (_RPCServer.FWalletKeys.IsValidPassword)) then begin
      // Wallet is password protected
      ErrorDesc := 'Wallet is password protected';
      ErrorNum := CT_RPC_ErrNum_WalletPasswordProtected;
      Exit;
    end;
    if Not HexaStringToOperationsHashTreeAndGetMultioperation(FNode.Bank.SafeBox.CurrentProtocol, HexaStringOperationsHashTree,False,senderOperationsHashTree,mop,errors) then begin
      ErrorNum:=CT_RPC_ErrNum_InvalidData;
      ErrorDesc:= 'Error decoding param previous operations hash tree raw value: '+errors;
      Exit;
    end;
    Try
      nSignedAccounts := 0;
      lSigners := TList<Cardinal>.Create;
      Try
        mop.SignerAccounts(lSigners);
        for j:=0 to lSigners.Count-1 do begin
          nAccount := PtrInt(lSigners[j]);
          if (nAccount>=0) And (nAccount<FNode.Bank.AccountsCount) then begin
            // Try to
            pubKey := FNode.GetMempoolAccount(nAccount).accountInfo.accountKey;
            // Is mine?
            iKey := _RPCServer.FWalletKeys.IndexOfAccountKey(pubKey);
            if (iKey>=0) then begin
              if (assigned(_RPCServer.FWalletKeys.Key[iKey].PrivateKey)) then begin
                // Can sign
                inc(nSignedAccounts, mop.DoSignMultiOperationSigner(FNode.Bank.SafeBox.CurrentProtocol,nAccount,_RPCServer.FWalletKeys.Key[iKey].PrivateKey) );
              end;
            end;
          end;
        end;
      finally
        lSigners.Free;
      end;
      // Return multioperation object:
      TPascalCoinJSONComp.FillMultiOperationObject(FNode.Bank.SafeBox.CurrentProtocol,mop,GetResultObject);
      Result := True;
    finally
      senderOperationsHashTree.Free;
    end;
  end;

  function RawOperations_Delete(Const HexaStringOperationsHashTree : String; index : Integer) : boolean;
  var senderOperationsHashTree : TOperationsHashTree;
    errors : String;
  begin
    Result := False;
    if Not TPascalCoinJSONComp.HexaStringToOperationsHashTree(HexaStringOperationsHashTree,CT_BUILD_PROTOCOL,senderOperationsHashTree,errors) then begin
      ErrorNum:=CT_RPC_ErrNum_InvalidData;
      ErrorDesc:= 'Error decoding param previous operations hash tree raw value: '+errors;
      Exit;
    end;
    Try
      // Obtain mop from last OperationsHashTree operation, otherwise create a new one
      if (index>=0) And (index<senderOperationsHashTree.OperationsCount) then begin
        senderOperationsHashTree.Delete(index);
      end else begin
        ErrorNum := CT_RPC_ErrNum_InvalidData;
        ErrorDesc:='Cannot delete index '+IntToStr(index)+' from Raw operations length '+IntToStr(senderOperationsHashTree.OperationsCount);
        Exit;
      end;
      // Return objects:
      TPascalCoinJSONComp.FillOperationsHashTreeObject(senderOperationsHashTree,GetResultObject);
      Result := True;
    finally
      senderOperationsHashTree.Free;
    end;
  end;

Var c,c2,c3 : Cardinal;
  i,j,k,l : Integer;
  account : TAccount;
  senderpubkey,destpubkey : TAccountKey;
  ansistr : String;
  nsaarr : TNodeServerAddressArray;
  pcops : TPCOperationsComp;
  ecpkey : TECPrivateKey;
  opr : TOperationResume;
  r1,r2 : TRawBytes;
  ocl : TOrderedCardinalList;
  jsonarr : TPCJSONArray;
  jso : TPCJSONObject;
  LRPCProcessMethod : TRPCProcessMethod;
begin
  _ro := Nil;
  _ra := Nil;
  ErrorNum:=0;
  ErrorDesc:='';
  Result := false;
  {$IFDEF HIGHLOG}TLog.NewLog(ltdebug,ClassName,'Processing RPC-JSON method '+method);{$ENDIF}
  if (method='addnode') then begin
    // Param "nodes" contains ip's and ports in format "ip1:port1;ip2:port2 ...". If port is not specified, use default
    // Returns quantity of nodes added
    if (Not _RPCServer.AllowUsePrivateKeys) then begin
      // Protection when server is locked to avoid external calls
      ErrorNum := CT_RPC_ErrNum_NotAllowedCall;
      Exit;
    end;
    TNode.DecodeIpStringToNodeServerAddressArray(params.AsString('nodes',''),nsaarr);
    for i:=low(nsaarr) to high(nsaarr) do begin
      TNetData.NetData.AddServer(nsaarr[i]);
    end;
    jsonresponse.GetAsVariant('result').Value:=length(nsaarr);
    Result := true;
  end else if (method='getaccount') then begin
    // Param "account" contains account number
    // Returns JSON Object with account information based on BlockChain + Pending operations
    if Not CaptureAccountNumber('account',True,c,ErrorDesc) then begin
      ErrorNum := CT_RPC_ErrNum_InvalidAccount;
    end else begin
      account := FNode.GetMempoolAccount(c);
      TPascalCoinJSONComp.FillAccountObject(account,GetResultObject);
      Result := True;
    end;
  end else if (method='getwalletaccounts') then begin
    if (Not _RPCServer.AllowUsePrivateKeys) then begin
      // Protection when server is locked to avoid private keys call
      ErrorNum := CT_RPC_ErrNum_NotAllowedCall;
      Exit;
    end;

    // Returns JSON array with accounts in Wallet
    jsonarr := jsonresponse.GetAsArray('result');
    if (params.IndexOfName('enc_pubkey')>=0) Or (params.IndexOfName('b58_pubkey')>=0) then begin
      if Not (CapturePubKey('',opr.newKey,ErrorDesc)) then begin
        ErrorNum := CT_RPC_ErrNum_InvalidPubKey;
        exit;
      end;
      i := _RPCServer.WalletKeys.AccountsKeyList.IndexOfAccountKey(opr.newKey);
      if (i<0) then begin
        ErrorNum := CT_RPC_ErrNum_NotFound;
        ErrorDesc := 'Public key not found in wallet';
        exit;
      end;
      ocl := _RPCServer.WalletKeys.AccountsKeyList.AccountKeyList[i];
      k := params.AsInteger('max',100);
      l := params.AsInteger('start',0);
      for j := 0 to ocl.Count - 1 do begin
        if (j>=l) then begin
          account := FNode.GetMempoolAccount(ocl.Get(j));
          TPascalCoinJSONComp.FillAccountObject(account,jsonarr.GetAsObject(jsonarr.Count));
        end;
        if (k>0) And ((j+1)>=(k+l)) then break;
      end;
      Result := true;
    end else begin
      k := params.AsInteger('max',100);
      l := params.AsInteger('start',0);
      c := 0;
      for i:=0 to _RPCServer.WalletKeys.AccountsKeyList.Count-1 do begin
        ocl := _RPCServer.WalletKeys.AccountsKeyList.AccountKeyList[i];
        for j := 0 to ocl.Count - 1 do begin
          if (c>=l) then begin
            account := FNode.GetMempoolAccount(ocl.Get(j));
            TPascalCoinJSONComp.FillAccountObject(account,jsonarr.GetAsObject(jsonarr.Count));
          end;
          inc(c);
          if (k>0) And (c>=(k+l)) then break;
        end;
        if (k>0) And (c>=(k+l)) then break;
      end;
      Result := true;
    end;
  end else if (method='getwalletaccountscount') then begin
    if (Not _RPCServer.AllowUsePrivateKeys) then begin
      // Protection when server is locked to avoid private keys call
      ErrorNum := CT_RPC_ErrNum_NotAllowedCall;
      Exit;
    end;
    // New Build 1.1.1
    // Returns a number with count value
    if (params.IndexOfName('enc_pubkey')>=0) Or (params.IndexOfName('b58_pubkey')>=0) then begin
      if Not (CapturePubKey('',opr.newKey,ErrorDesc)) then begin
        ErrorNum := CT_RPC_ErrNum_InvalidPubKey;
        exit;
      end;
      i := _RPCServer.WalletKeys.AccountsKeyList.IndexOfAccountKey(opr.newKey);
      if (i<0) then begin
        ErrorNum := CT_RPC_ErrNum_NotFound;
        ErrorDesc := 'Public key not found in wallet';
        exit;
      end;
      ocl := _RPCServer.WalletKeys.AccountsKeyList.AccountKeyList[i];
      jsonresponse.GetAsVariant('result').value := ocl.count;
      Result := true;
    end else begin
      ErrorDesc := '';
      c :=0;
      for i:=0 to _RPCServer.WalletKeys.AccountsKeyList.Count-1 do begin
        ocl := _RPCServer.WalletKeys.AccountsKeyList.AccountKeyList[i];
        inc(c,ocl.count);
      end;
      jsonresponse.GetAsVariant('result').value := c;
      Result := true;
    end;
  end else if (method='getwalletcoins') then begin
    if (Not _RPCServer.AllowUsePrivateKeys) then begin
      // Protection when server is locked to avoid private keys call
      ErrorNum := CT_RPC_ErrNum_NotAllowedCall;
      Exit;
    end;
    if (params.IndexOfName('enc_pubkey')>=0) Or (params.IndexOfName('b58_pubkey')>=0) then begin
      if Not (CapturePubKey('',opr.newKey,ErrorDesc)) then begin
        ErrorNum := CT_RPC_ErrNum_InvalidPubKey;
        exit;
      end;
      i := _RPCServer.WalletKeys.AccountsKeyList.IndexOfAccountKey(opr.newKey);
      if (i<0) then begin
        ErrorNum := CT_RPC_ErrNum_NotFound;
        ErrorDesc := 'Public key not found in wallet';
        exit;
      end;
      ocl := _RPCServer.WalletKeys.AccountsKeyList.AccountKeyList[i];
      account.balance := 0;
      for j := 0 to ocl.Count - 1 do begin
        inc(account.balance, FNode.GetMempoolAccount(ocl.Get(j)).balance );
      end;
      jsonresponse.GetAsVariant('result').value := ToJSONCurrency(account.balance);
      Result := true;
    end else begin
      ErrorDesc := '';
      c :=0;
      account.balance := 0;
      for i:=0 to _RPCServer.WalletKeys.AccountsKeyList.Count-1 do begin
        ocl := _RPCServer.WalletKeys.AccountsKeyList.AccountKeyList[i];
        for j := 0 to ocl.Count - 1 do begin
          inc(account.balance, FNode.GetMempoolAccount(ocl.Get(j)).balance );
        end;
      end;
      jsonresponse.GetAsVariant('result').value := ToJSONCurrency(account.balance);
      Result := true;
    end;
  end else if (method='getwalletpubkeys') then begin
    if (Not _RPCServer.AllowUsePrivateKeys) then begin
      // Protection when server is locked to avoid private keys call
      ErrorNum := CT_RPC_ErrNum_NotAllowedCall;
      Exit;
    end;
    // Returns JSON array with pubkeys in wallet
    k := params.AsInteger('max',100);
    j := params.AsInteger('start',0);
    jsonarr := jsonresponse.GetAsArray('result');
    for i:=0 to _RPCServer.WalletKeys.Count-1 do begin
      if (i>=j) then begin
        jso := jsonarr.GetAsObject(jsonarr.count);
        jso.GetAsVariant('name').Value := _RPCServer.WalletKeys.Key[i].Name;
        jso.GetAsVariant('can_use').Value := Length(_RPCServer.WalletKeys.Key[i].CryptedKey)>0;
        TPascalCoinJSONComp.FillPublicKeyObject(_RPCServer.WalletKeys.Key[i].AccountKey,jso);
      end;
      if (k>0) And ((i+1)>=(j+k)) then break;
    end;
    Result := true;
  end else if (method='getwalletpubkey') then begin
    if (Not _RPCServer.AllowUsePrivateKeys) then begin
      // Protection when server is locked to avoid private keys call
      ErrorNum := CT_RPC_ErrNum_NotAllowedCall;
      Exit;
    end;
    if Not (CapturePubKey('',opr.newKey,ErrorDesc)) then begin
      ErrorNum := CT_RPC_ErrNum_InvalidPubKey;
      exit;
    end;
    i := _RPCServer.WalletKeys.AccountsKeyList.IndexOfAccountKey(opr.newKey);
    if (i<0) then begin
      ErrorNum := CT_RPC_ErrNum_NotFound;
      ErrorDesc := 'Public key not found in wallet';
      exit;
    end;
    TPascalCoinJSONComp.FillPublicKeyObject(_RPCServer.WalletKeys.AccountsKeyList.AccountKey[i],GetResultObject);
    Result := true;
  end else if (method='importpubkey') then begin
       ansistr:= params.AsString('name','');

       if ((params.IndexOfName('b58_pubkey')>=0) AND (ansistr<>'')) then begin
         if Not (CapturePubKey('',destpubkey,ErrorDesc)) then begin
            ErrorNum := CT_RPC_ErrNum_InvalidPubKey;
            exit;
         end;
         _RPCServer.WalletKeys.AddPublicKey(ansistr,destpubkey);
       end else begin
         ErrorNum := CT_RPC_ErrNum_InvalidData;
         ErrorDesc := 'Needed both parameters b58_pubkey and name';
         exit;
    end;
    TPascalCoinJSONComp.FillPublicKeyObject(destpubkey,GetResultObject);
    Result := true;
  end else if (method='getblock') then begin
    // Param "block" contains block number (0..getblockcount-1)
    // Returns JSON object with block information
    c := params.GetAsVariant('block').AsCardinal(CT_MaxBlock);
    if (c>=0) And (c<FNode.Bank.BlocksCount) then begin
      Result := GetBlock(c,GetResultObject);
    end else begin
      ErrorNum := CT_RPC_ErrNum_InvalidBlock;
      if (c=CT_MaxBlock) then ErrorDesc := 'Need block param'
      else ErrorDesc := 'Block not found: '+IntToStr(c);
    end;
  end else if (method='getblocks') then begin
    // Param "start" "end" contains blocks number (0..getblockcount-1)
    // Returns JSON Array with blocks information (limited to 1000 blocks)
    // Sorted by DESCENDING blocknumber
    i := params.AsCardinal('last',0);
    if (i>0) then begin
      if (i>1000) then i := 1000;
      c2 := FNode.Bank.BlocksCount-1;
      if (FNode.Bank.BlocksCount>=i) then
        c := (FNode.Bank.BlocksCount) - i
      else c := 0;
    end else begin
      c := params.GetAsVariant('start').AsCardinal(CT_MaxBlock);
      c2 := params.GetAsVariant('end').AsCardinal(CT_MaxBlock);
      i := params.AsInteger('max',0);
      if (c<FNode.Bank.BlocksCount) And (i>0) And (i<=1000) then begin
        if (c+i<FNode.Bank.BlocksCount) then c2 := c+i
        else c2 := FNode.Bank.BlocksCount-1;
      end;
    end;
    if ((c>=0) And (c<FNode.Bank.BlocksCount)) And (c2>=c) And (c2<FNode.Bank.BlocksCount) then begin
      i := 0; Result := true;
      while (c<=c2) And (Result) And (i<1000) do begin
        Result := GetBlock(c2,jsonresponse.GetAsArray('result').GetAsObject(i));
        dec(c2); inc(i);
      end;
    end else begin
      ErrorNum := CT_RPC_ErrNum_InvalidBlock;
      if (c>c2) then ErrorDesc := 'Block start > block end'
      else if (c=CT_MaxBlock) Or (c2=CT_MaxBlock) then ErrorDesc:='Need param "last" or "start" and "end"/"max"'
      else if (c2>=FNode.Bank.BlocksCount) then ErrorDesc := 'Block higher or equal to getblockccount: '+IntToStr(c2)
      else  ErrorDesc := 'Block not found: '+IntToStr(c);
    end;
  end else if (method='getblockcount') then begin
    // Returns a number with Node blocks count
    jsonresponse.GetAsVariant('result').Value:=FNode.Bank.BlocksCount;
    Result := True;
  end else if (method='getblockoperation') then begin
    // Param "block" contains block. Null = Pending operation
    // Param "opblock" contains operation inside a block: (0..getblock.operations-1)
    // Returns a JSON object with operation values as "Operation resume format"
    c := params.GetAsVariant('block').AsCardinal(CT_MaxBlock);
    if (c>=0) And (c<FNode.Bank.BlocksCount) then begin
      pcops := TPCOperationsComp.Create(Nil);
      try
        If Not FNode.Bank.LoadOperations(pcops,c) then begin
          ErrorNum := CT_RPC_ErrNum_InternalError;
          ErrorDesc := 'Cannot load Block: '+IntToStr(c);
          Exit;
        end;
        i := params.GetAsVariant('opblock').AsInteger(0);
        if (i<0) Or (i>=pcops.Count) then begin
          ErrorNum := CT_RPC_ErrNum_InvalidOperation;
          ErrorDesc := 'Block/Operation not found: '+IntToStr(c)+'/'+IntToStr(i)+' BlockOperations:'+IntToStr(pcops.Count);
          Exit;
        end;
        If TPCOperation.OperationToOperationResume(c,pcops.Operation[i],True,pcops.Operation[i].SignerAccount,opr) then begin
          opr.NOpInsideBlock:=i;
          opr.time:=pcops.OperationBlock.timestamp;
          opr.Balance := -1;
          FillOperationResumeToJSONObject(opr,GetResultObject);
        end;
        Result := True;
      finally
        pcops.Free;
      end;
    end else begin
      If (c=CT_MaxBlock) then ErrorDesc := 'Need block param'
      else ErrorDesc := 'Block not found: '+IntToStr(c);
      ErrorNum := CT_RPC_ErrNum_InvalidBlock;
    end;
  end else if (method='getblockoperations') then begin
    // Param "block" contains block
    // Returns a JSON array with items as "Operation resume format"
    c := params.GetAsVariant('block').AsCardinal(CT_MaxBlock);
    if (c>=0) And (c<FNode.Bank.BlocksCount) then begin
      pcops := TPCOperationsComp.Create(Nil);
      try
        If Not FNode.Bank.LoadOperations(pcops,c) then begin
          ErrorNum := CT_RPC_ErrNum_InternalError;
          ErrorDesc := 'Cannot load Block: '+IntToStr(c);
          Exit;
        end;
        jsonarr := GetResultArray;
        k := params.AsInteger('max',100);
        j := params.AsInteger('start',0);
        for i := 0 to pcops.Count - 1 do begin
          if (i>=j) then begin
            If TPCOperation.OperationToOperationResume(c,pcops.Operation[i],True,pcops.Operation[i].SignerAccount,opr) then begin
              opr.NOpInsideBlock:=i;
              opr.time:=pcops.OperationBlock.timestamp;
              opr.Balance := -1; // Don't include!
              FillOperationResumeToJSONObject(opr,jsonarr.GetAsObject(jsonarr.Count));
            end;
          end;
          if (k>0) And ((i+1)>=(j+k)) then break;
        end;
        Result := True;
      finally
        pcops.Free;
      end;
    end else begin
      If (c=CT_MaxBlock) then ErrorDesc := 'Need block param'
      else ErrorDesc := 'Block not found: '+IntToStr(c);
      ErrorNum := CT_RPC_ErrNum_InvalidBlock;
    end;
  end else if (method='getaccountoperations') then begin
    // Returns all the operations affecting an account in "Operation resume format" as an array
    // Param "account" contains account number
    // Param "depht" (optional or "deep") contains max blocks deep to search (Default: 100)
    // Param "start" and "max" contains starting index and max operations respectively
    // Param "startblock" forces to start searching backwards on a fixed block, will not give balance for each operation due it's unknown
    if CaptureAccountNumber('account',True,c,ErrorDesc) then begin
      if (params.IndexOfName('depth')>=0) then i := params.AsInteger('depth',100) else i:=params.AsInteger('deep',100);
      If params.IndexOfName('startblock')>=0 then c2 := params.AsCardinal('startblock',0)
      else c2 := 0;
      Result := GetAccountOperations(c,GetResultArray,i,params.AsInteger('start',0),params.AsInteger('max',100),c2);
    end else begin
      ErrorNum := CT_RPC_ErrNum_InvalidAccount;
    end;
  end else if (method='getpendings') then begin
    // Returns all the operations pending to be included in a block in "Operation resume format" as an array
    // Create result
    k := params.AsInteger('max',100);
    j := params.AsInteger('start',0);
    If FNode.TryLockNode(5000) then begin
      Try
        jsonarr := GetResultArray;
        pcops := FNode.LockMempoolRead;
        try
          for i := j to pcops.Count-1 do begin
            If TPCOperation.OperationToOperationResume(0,pcops.Operation[i],True,pcops.Operation[i].SignerAccount,opr) then begin
              opr.NOpInsideBlock:=i;
              opr.Balance := -1; // Don't include!
              FillOperationResumeToJSONObject(opr,jsonarr.GetAsObject(jsonarr.Count));
            end;
            if (k>0) And (jsonarr.Count>=k) then break;
          end;
        finally
          FNode.UnlockMempoolRead;
        end;
      finally
        FNode.UnlockNode;
      end;
      Result := true;
    end else begin
      ErrorNum := CT_RPC_ErrNum_InternalError;
      ErrorDesc := 'Node is busy';
    end;
  end else if (method='getpendingscount') then begin
    jsonresponse.GetAsVariant('result').Value := FNode.MempoolOperationsCount;
    Result := true;
  end else if (method='decodeophash') then begin
    // Search for an operation based on "ophash"
    r1 := TCrypto.HexaToRaw(params.AsString('ophash',''));
    if (Length(r1)=0) then begin
      ErrorNum:=CT_RPC_ErrNum_NotFound;
      ErrorDesc:='param ophash not found or invalid hexadecimal value "'+params.AsString('ophash','')+'"';
      exit;
    end;
    If not TPCOperation.DecodeOperationHash(r1,c,c2,c3,r2) then begin
      ErrorNum:=CT_RPC_ErrNum_NotFound;
      ErrorDesc:='invalid ophash param value';
      exit;
    end;
    GetResultObject.GetAsVariant('block').Value:=c;
    GetResultObject.GetAsVariant('account').Value:=c2;
    GetResultObject.GetAsVariant('n_operation').Value:=c3;
    GetResultObject.GetAsVariant('md160hash').Value:=TCrypto.ToHexaString(r2);
    Result := true;
  end else if (method='findoperation') then begin
    // Search for an operation based on "ophash"
    r1 := TCrypto.HexaToRaw(params.AsString('ophash',''));
    if (Length(r1)=0) then begin
      ErrorNum:=CT_RPC_ErrNum_NotFound;
      ErrorDesc:='param ophash not found or invalid hexadecimal value "'+params.AsString('ophash','')+'"';
      exit;
    end;
    pcops := TPCOperationsComp.Create(Nil);
    try
      Case FNode.FindOperationExt(pcops,r1,c,i) of
        found : ;
        invalid_params : begin
            ErrorNum:=CT_RPC_ErrNum_NotFound;
            ErrorDesc:='ophash not found: "'+params.AsString('ophash','')+'"';
            exit;
          end;
        blockchain_block_not_found : begin
            ErrorNum := CT_RPC_ErrNum_InternalError;
            ErrorDesc:='Blockchain block '+IntToStr(c)+' not found to search ophash: "'+params.AsString('ophash','')+'"';
            exit;
          end;
      else Raise Exception.Create('ERROR DEV 20171120-4');
      end;
      If not TPCOperation.OperationToOperationResume(c,pcops.Operation[i],True,pcops.Operation[i].SignerAccount,opr) then begin
        ErrorNum := CT_RPC_ErrNum_InternalError;
        ErrorDesc := 'Error 20161026-1';
      end;
      opr.NOpInsideBlock:=i;
      opr.time:=pcops.OperationBlock.timestamp;
      opr.Balance := -1; // don't include
      FillOperationResumeToJSONObject(opr,GetResultObject);
      Result := True;
    finally
      pcops.Free;
    end;
  end else if (method='findnoperation') then begin
    // Search for an operation signed by "account" and with "n_operation", start searching "block" (0=all)
    // "block" = 0 search in all blocks, pending operations included
    if Not CaptureAccountNumber('account',True,c,ErrorDesc) then begin
      ErrorNum := CT_RPC_ErrNum_InvalidAccount;
      Exit;
    end;
    Case FNode.FindNOperation(params.AsCardinal('block',0),c,params.AsCardinal('n_operation',0),opr) of
      found : ;
      invalid_params : begin
          ErrorNum:=CT_RPC_ErrNum_NotFound;
          ErrorDesc:='Not found using block/account/n_operation';
          exit;
        end;
      blockchain_block_not_found : begin
          ErrorNum := CT_RPC_ErrNum_InvalidBlock;
          ErrorDesc:='Blockchain file does not contain all blocks to find';
          exit;
        end;
    else Raise Exception.Create('ERROR DEV 20171120-5');
    end;
    FillOperationResumeToJSONObject(opr,GetResultObject);
    Result := True;
  end else if (method='findnoperations') then begin
    // Search for all operations signed by "account" and n_operation value between "n_operation_min" and "n_operation_max", start searching at "block" (0=all)
    // "block" = 0 search in all blocks, pending operations included
    Result := findNOperations;
  end else if (method='sendto') then begin
    // Sends "amount" coins from "sender" to "target" with "fee"
    // If "payload" is present, it will be encoded using "payload_method"
    // "payload_method" types: "none","dest"(default),"sender","aes"(must provide "pwd" param)
    // Returns a JSON "Operation Resume format" object when successfull
    // Note: "ophash" will contain block "0" = "pending block"
    if (Not _RPCServer.AllowUsePrivateKeys) then begin
      // Protection when server is locked to avoid private keys call
      ErrorNum := CT_RPC_ErrNum_NotAllowedCall;
      Exit;
    end;
    If Not _RPCServer.WalletKeys.IsValidPassword then begin
      ErrorNum := CT_RPC_ErrNum_WalletPasswordProtected;
      ErrorDesc := 'Wallet is password protected. Unlock first';
      exit;
    end;
    if Not CaptureAccountNumber('sender',True,c2,ErrorDesc) then begin
      ErrorNum := CT_RPC_ErrNum_InvalidAccount;
      Exit;
    end;
    if Not CaptureAccountNumber('target',True,c3,ErrorDesc) then begin
      ErrorNum := CT_RPC_ErrNum_InvalidAccount;
      Exit;
    end;
    Result := OpSendTo(c2,c3,
       ToPascalCoins(params.AsDouble('amount',0)),
       ToPascalCoins(params.AsDouble('fee',0)),
       TCrypto.HexaToRaw(params.AsString('payload','')),
       params.AsString('payload_method','dest'),params.AsString('pwd',''));
  end else if (method='signsendto') then begin
    // Create a Transaction operation and adds it into a "rawoperations" (that can include
    // previous operations). This RPC method is usefull ffor cold storage, because doesn't
    // need to check or verify accounts status/public key, assuming that passed values
    // are ok.
    // Signs a transaction of "amount" coins from "sender" to "target" with "fee", using "sender_enc_pubkey" or "sender_b58_pubkey"
    // and "last_n_operation" of sender. Also, needs "target_enc_pubkey" or "target_b58_pubkey"
    // If "payload" is present, it will be encoded using "payload_method"
    // "payload_method" types: "none","dest"(default),"sender","aes"(must provide "pwd" param)
    // Returns a JSON "Operations info" containing old "rawoperations" plus new Transaction
    if (Not _RPCServer.AllowUsePrivateKeys) then begin
      // Protection when server is locked to avoid private keys call
      ErrorNum := CT_RPC_ErrNum_NotAllowedCall;
      Exit;
    end;
    If Not _RPCServer.WalletKeys.IsValidPassword then begin
      ErrorNum := CT_RPC_ErrNum_WalletPasswordProtected;
      ErrorDesc := 'Wallet is password protected. Unlock first';
      exit;
    end;
    if Not CaptureAccountNumber('sender',False,c2,ErrorDesc) then begin
      ErrorNum := CT_RPC_ErrNum_InvalidAccount;
      Exit;
    end;
    if Not CaptureAccountNumber('target',False,c3,ErrorDesc) then begin
      ErrorNum := CT_RPC_ErrNum_InvalidAccount;
      Exit;
    end;
    If Not CapturePubKey('sender_',senderpubkey,ErrorDesc) then begin
      ErrorNum := CT_RPC_ErrNum_InvalidPubKey;
      exit;
    end;
    If Not CapturePubKey('target_',destpubkey,ErrorDesc) then begin
      ErrorNum := CT_RPC_ErrNum_InvalidPubKey;
      exit;
    end;
    Result := SignOpSendTo(
       params.AsString('rawoperations',''),
       params.AsCardinal('protocol',CT_BUILD_PROTOCOL),
       c2,c3,
       senderpubkey,destpubkey,
       params.AsCardinal('last_n_operation',0),
       ToPascalCoins(params.AsDouble('amount',0)),
       ToPascalCoins(params.AsDouble('fee',0)),
       TCrypto.HexaToRaw(params.AsString('payload','')),
       params.AsString('payload_method','dest'),params.AsString('pwd',''));
  end else if (method='changekey') then begin
    // Change key of "account" to "new_enc_pubkey" or "new_b58_pubkey" (encoded public key format) with "fee"
    // If "payload" is present, it will be encoded using "payload_method"
    // "payload_method" types: "none","dest"(default),"sender","aes"(must provide "pwd" param)
    // Returns a JSON "Operation Resume format" object when successfull
    // Note: "ophash" will contain block "0" = "pending block"
    if (Not _RPCServer.AllowUsePrivateKeys) then begin
      // Protection when server is locked to avoid private keys call
      ErrorNum := CT_RPC_ErrNum_NotAllowedCall;
      Exit;
    end;
    If Not _RPCServer.WalletKeys.IsValidPassword then begin
      ErrorNum := CT_RPC_ErrNum_WalletPasswordProtected;
      ErrorDesc := 'Wallet is password protected. Unlock first';
      exit;
    end;
    if Not CaptureAccountNumber('account',True,c,ErrorDesc) then begin
      ErrorNum := CT_RPC_ErrNum_InvalidAccount;
      Exit;
    end;
    if Not CaptureAccountNumber('account_signer',True,c2,ansistr) then begin
      c2 := c;
    end;

    If Not CapturePubKey('new_',account.accountInfo.accountKey,ErrorDesc) then begin
      ErrorNum := CT_RPC_ErrNum_InvalidPubKey;
      exit;
    end;
    Result := ChangeAccountKey(c2,c,
       account.accountInfo.accountKey,
       ToPascalCoins(params.AsDouble('fee',0)),
       TCrypto.HexaToRaw(params.AsString('payload','')),
       params.AsString('payload_method','dest'),params.AsString('pwd',''));
  end else if (method='changekeys') then begin
    // Allows a massive change key operation
    // Change key of "accounts" to "new_enc_pubkey" or "new_b58_pubkey" (encoded public key format) with "fee"
    // If "payload" is present, it will be encoded using "payload_method"
    // "payload_method" types: "none","dest"(default),"sender","aes"(must provide "pwd" param)
    // Returns a JSON object with result information
    if (Not _RPCServer.AllowUsePrivateKeys) then begin
      // Protection when server is locked to avoid private keys call
      ErrorNum := CT_RPC_ErrNum_NotAllowedCall;
      Exit;
    end;
    If Not _RPCServer.WalletKeys.IsValidPassword then begin
      ErrorNum := CT_RPC_ErrNum_WalletPasswordProtected;
      ErrorDesc := 'Wallet is password protected. Unlock first';
      exit;
    end;
    if params.IndexOfName('accounts')<0 then begin
      ErrorNum := CT_RPC_ErrNum_InvalidAccount;
      ErrorDesc := 'Need "accounts" param';
      exit;
    end;
    If Not CapturePubKey('new_',account.accountInfo.accountKey,ErrorDesc) then begin
      ErrorNum := CT_RPC_ErrNum_InvalidPubKey;
      exit;
    end;
    Result := ChangeAccountsKey(params.AsString('accounts',''),
       account.accountInfo.accountKey,
       ToPascalCoins(params.AsDouble('fee',0)),
       TCrypto.HexaToRaw(params.AsString('payload','')),
       params.AsString('payload_method','dest'),params.AsString('pwd',''));
  end else if (method='signchangekey') then begin
    // Create a Change Key operation and adds it into a "rawoperations" (that can include
    // previous operations). This RPC method is usefull for cold storage, because doesn't
    // need to check or verify accounts status/public key, assuming that passed values
    // are ok.
    // Signs a change key of "account" to "new_enc_pubkey" or "new_b58_pubkey" (encoded public key format) with "fee"
    // needs "old_enc_pubkey" or "old_b58_pubkey" that will be used to find private key in wallet to sign
    // and "last_n_operation" of account.
    // If "payload" is present, it will be encoded using "payload_method"
    // "payload_method" types: "none","dest"(default),"sender","aes"(must provide "pwd" param)
    // Returns a JSON "Operations info" containing old "rawoperations" plus new Transaction
    if (Not _RPCServer.AllowUsePrivateKeys) then begin
      // Protection when server is locked to avoid private keys call
      ErrorNum := CT_RPC_ErrNum_NotAllowedCall;
      Exit;
    end;
    If Not _RPCServer.WalletKeys.IsValidPassword then begin
      ErrorNum := CT_RPC_ErrNum_WalletPasswordProtected;
      ErrorDesc := 'Wallet is password protected. Unlock first';
      exit;
    end;
    if Not CaptureAccountNumber('account',True,c,ErrorDesc) then begin
      ErrorNum := CT_RPC_ErrNum_InvalidAccount;
      Exit;
    end;
    if Not CaptureAccountNumber('account_signer',True,c2,ansistr) then begin
      c2 := c;
    end;
    If Not CapturePubKey('old_',senderpubkey,ErrorDesc) then begin
      ErrorNum := CT_RPC_ErrNum_InvalidPubKey;
      exit;
    end;
    If Not CapturePubKey('new_',destpubkey,ErrorDesc) then begin
      ErrorNum := CT_RPC_ErrNum_InvalidPubKey;
      exit;
    end;
    Result := SignOpChangeKey(params.AsString('rawoperations',''),
       params.AsCardinal('protocol',CT_BUILD_PROTOCOL),
       c2,c,
       senderpubkey,destpubkey,
       params.AsCardinal('last_n_operation',0),
       ToPascalCoins(params.AsDouble('fee',0)),
       TCrypto.HexaToRaw(params.AsString('payload','')),
       params.AsString('payload_method','dest'),params.AsString('pwd',''));
  end else if (method='listaccountforsale') then begin
    // Will put a single account in "for sale" state
    if (Not _RPCServer.AllowUsePrivateKeys) then begin
      // Protection when server is locked to avoid private keys call
      ErrorNum := CT_RPC_ErrNum_NotAllowedCall;
      Exit;
    end;
    Result := ListAccountForSale;
  end else if (method='signlistaccountforsale') then begin
    if (Not _RPCServer.AllowUsePrivateKeys) then begin
      // Protection when server is locked to avoid private keys call
      ErrorNum := CT_RPC_ErrNum_NotAllowedCall;
      Exit;
    end;
    Result := SignListAccountForSaleColdWallet(params.AsString('rawoperations',''));
  end else if (method='delistaccountforsale') then begin
    if (Not _RPCServer.AllowUsePrivateKeys) then begin
      // Protection when server is locked to avoid private keys call
      ErrorNum := CT_RPC_ErrNum_NotAllowedCall;
      Exit;
    end;
    Result := DelistAccountForSale(params);
  end else if (method='signdelistaccountforsale') then begin
    if (Not _RPCServer.AllowUsePrivateKeys) then begin
      // Protection when server is locked to avoid private keys call
      ErrorNum := CT_RPC_ErrNum_NotAllowedCall;
      Exit;
    end;
    Result := SignDelistAccountForSaleColdWallet(params.AsString('rawoperations',''));
  end else if (method='buyaccount') then begin
    if (Not _RPCServer.AllowUsePrivateKeys) then begin
      // Protection when server is locked to avoid private keys call
      ErrorNum := CT_RPC_ErrNum_NotAllowedCall;
      Exit;
    end;
    Result := BuyAccount;
  end else if (method='signbuyaccount') then begin
    if (Not _RPCServer.AllowUsePrivateKeys) then begin
      // Protection when server is locked to avoid private keys call
      ErrorNum := CT_RPC_ErrNum_NotAllowedCall;
      Exit;
    end;
    Result := SignBuyAccountColdWallet(params.AsString('rawoperations',''));
  end else if (method='changeaccountinfo') then begin
    if (Not _RPCServer.AllowUsePrivateKeys) then begin
      // Protection when server is locked to avoid private keys call
      ErrorNum := CT_RPC_ErrNum_NotAllowedCall;
      Exit;
    end;
    Result := ChangeAccountInfo;
  end else if (method='signchangeaccountinfo') then begin
    if (Not _RPCServer.AllowUsePrivateKeys) then begin
      // Protection when server is locked to avoid private keys call
      ErrorNum := CT_RPC_ErrNum_NotAllowedCall;
      Exit;
    end;
    Result := SignChangeAccountInfoColdWallet(params.AsString('rawoperations',''));
  // V3 new calls
  end else if (method='signmessage') then begin
    if (Not _RPCServer.AllowUsePrivateKeys) then begin
      // Protection when server is locked to avoid private keys call
      ErrorNum := CT_RPC_ErrNum_NotAllowedCall;
      Exit;
    end;
    params.DeleteName('signature');
    Result := DoSignOrVerifyMessage(params);
  end else if (method='verifysign') then begin
    if (params.IndexOfName('signature')<0) then params.GetAsVariant('signature').Value:=''; // Init signature value to force verify
    Result := DoSignOrVerifyMessage(params);
  end else if (method='operationsdelete') then begin
    Result := RawOperations_Delete(params.AsString('rawoperations',''),params.AsInteger('index',-1));
  // V3 Multioperation
  end else if (method='multioperationaddoperation') then begin
    Result := MultiOperationAddOperation(params.AsString('rawoperations',''));
  end else if (method='multioperationsignoffline') then begin
    if (Not _RPCServer.AllowUsePrivateKeys) then begin
      // Protection when server is locked to avoid private keys call
      ErrorNum := CT_RPC_ErrNum_NotAllowedCall;
      Exit;
    end;
    Result := MultiOperationSignCold(params.AsString('rawoperations',''));
  end else if (method='multioperationsignonline') then begin
    if (Not _RPCServer.AllowUsePrivateKeys) then begin
      // Protection when server is locked to avoid private keys call
      ErrorNum := CT_RPC_ErrNum_NotAllowedCall;
      Exit;
    end;
    Result := MultiOperationSignOnline(params.AsString('rawoperations',''));
  //
  end else if (method='operationsinfo') then begin
    Result := OperationsInfo(params.AsString('rawoperations',''),GetResultArray);
  end else if (method='executeoperations') then begin
    Result := ExecuteOperations(params.AsString('rawoperations',''));

  //
  end else if (method='nodestatus') then begin
    if (Not _RPCServer.AllowUsePrivateKeys) then begin
      // Protection when server is locked to avoid external calls
      ErrorNum := CT_RPC_ErrNum_NotAllowedCall;
      Exit;
    end;
    // Returns a JSON Object with Node status
    GetResultObject.GetAsVariant('ready').Value := False;
    If FNode.IsReady(ansistr) then begin
      GetResultObject.GetAsVariant('ready_s').Value := ansistr;
      if TNetData.NetData.NetStatistics.ActiveConnections>0 then begin
        GetResultObject.GetAsVariant('ready').Value := True;
        if TNetData.NetData.IsDiscoveringServers then begin
          GetResultObject.GetAsVariant('status_s').Value := 'Discovering servers';
        end else if TNetData.NetData.IsGettingNewBlockChainFromClient(ansistr) then begin
          GetResultObject.GetAsVariant('status_s').Value := ansistr;
        end else begin
          GetResultObject.GetAsVariant('status_s').Value := 'Running';
        end;
      end else begin
        GetResultObject.GetAsVariant('ready_s').Value := 'Alone in the world...';
      end;
    end else begin
      GetResultObject.GetAsVariant('ready_s').Value := ansistr;
    end;
    GetResultObject.GetAsVariant('port').Value:=FNode.NetServer.Port;
    GetResultObject.GetAsVariant('locked').Value:=Not _RPCServer.WalletKeys.IsValidPassword;
    GetResultObject.GetAsVariant('timestamp').Value:=UnivDateTimeToUnix(DateTime2UnivDateTime(now));
    GetResultObject.GetAsVariant('version').Value:=CT_ClientAppVersion;
    GetResultObject.GetAsObject('netprotocol').GetAsVariant('ver').Value := CT_NetProtocol_Version;
    GetResultObject.GetAsObject('netprotocol').GetAsVariant('ver_a').Value := CT_NetProtocol_Available;
    GetResultObject.GetAsVariant('blocks').Value:=FNode.Bank.BlocksCount;
    GetResultObject.GetAsVariant('sbh').Value:=TCrypto.ToHexaString(FNode.Bank.LastOperationBlock.initial_safe_box_hash);
    GetResultObject.GetAsVariant('pow').Value:=TCrypto.ToHexaString(FNode.Bank.LastOperationBlock.proof_of_work);
    GetResultObject.GetAsObject('netstats').GetAsVariant('active').Value:=TNetData.NetData.NetStatistics.ActiveConnections;
    GetResultObject.GetAsObject('netstats').GetAsVariant('clients').Value:=TNetData.NetData.NetStatistics.ClientsConnections;
    GetResultObject.GetAsObject('netstats').GetAsVariant('servers').Value:=TNetData.NetData.NetStatistics.ServersConnectionsWithResponse;
    GetResultObject.GetAsObject('netstats').GetAsVariant('servers_t').Value:=TNetData.NetData.NetStatistics.ServersConnections;
    GetResultObject.GetAsObject('netstats').GetAsVariant('total').Value:=TNetData.NetData.NetStatistics.TotalConnections;
    GetResultObject.GetAsObject('netstats').GetAsVariant('tclients').Value:=TNetData.NetData.NetStatistics.TotalClientsConnections;
    GetResultObject.GetAsObject('netstats').GetAsVariant('tservers').Value:=TNetData.NetData.NetStatistics.TotalServersConnections;
    GetResultObject.GetAsObject('netstats').GetAsVariant('breceived').Value:=TNetData.NetData.NetStatistics.BytesReceived;
    GetResultObject.GetAsObject('netstats').GetAsVariant('bsend').Value:=TNetData.NetData.NetStatistics.BytesSend;
    {$IFDEF Use_OpenSSL}
    GetResultObject.GetAsVariant('openssl').Value := IntToHex(OpenSSLVersion,8);
    {$ENDIF}
    nsaarr := TNetData.NetData.NodeServersAddresses.GetValidNodeServers(true,20);
    for i := low(nsaarr) to High(nsaarr) do begin
      jso := GetResultObject.GetAsArray('nodeservers').GetAsObject(i);
      jso.GetAsVariant('ip').Value := nsaarr[i].ip;
      jso.GetAsVariant('port').Value := nsaarr[i].port;
      jso.GetAsVariant('lastcon').Value := nsaarr[i].last_connection;
      jso.GetAsVariant('attempts').Value := nsaarr[i].total_failed_attemps_to_connect;
    end;
    Result := True;
  end else if (method='encodepubkey') then begin
    // Creates a encoded public key based on params
    // Param "ec_nid" can be 714=secp256k1 715=secp384r1 729=secp283k1 716=secp521r1
    // Param "x","y" are x and y ec public keys values in hexadecimal based on ec_nid
    // Returns a hexadecimal value containing encoded public key
    account.accountInfo.accountKey.EC_OpenSSL_NID:=params.AsInteger('ec_nid',0);
    account.accountInfo.accountKey.x:=TCrypto.HexaToRaw(params.AsString('x',''));
    account.accountInfo.accountKey.y:=TCrypto.HexaToRaw(params.AsString('y',''));
    if (account.accountInfo.accountKey.EC_OpenSSL_NID=0) Or (Length(account.accountInfo.accountKey.x)=0) Or (Length(account.accountInfo.accountKey.y)=0) then begin
      ErrorDesc:= 'Need params "ec_nid","x","y" to encodepubkey';
      ErrorNum:= CT_RPC_ErrNum_InvalidPubKey;
      exit;
    end;
    if TAccountComp.IsValidAccountKey(account.accountInfo.accountKey,CT_BUILD_PROTOCOL,ansistr) then begin
      jsonresponse.GetAsVariant('result').Value:=TCrypto.ToHexaString(TAccountComp.AccountKey2RawString(account.accountInfo.accountKey));
      Result := True;
    end else begin
      ErrorDesc:= ansistr;
      ErrorNum:= CT_RPC_ErrNum_InvalidPubKey;
    end;
  end else if (method='decodepubkey') then begin
    // Returns "ec_nid", "x" and "y" of an encoded public key (x and y in hexadecimal)
    // Must provide:
    // - Param "enc_pubkey" is an hexadecimal encoded public key (see 'encodepubkey')
    // or
    // - Param "b58_pubkey" is a Base58 encoded public key
    If Not CapturePubKey('',account.accountInfo.accountKey,ErrorDesc) then begin
      ErrorNum := CT_RPC_ErrNum_InvalidPubKey;
      exit;
    end;
    if (TAccountComp.IsValidAccountKey(account.accountInfo.accountKey,CT_BUILD_PROTOCOL,ansistr)) then begin
      TPascalCoinJSONComp.FillPublicKeyObject(account.accountInfo.accountKey,GetResultObject);
      Result := True;
    end else begin
      ErrorDesc:= ansistr;
      ErrorNum:= CT_RPC_ErrNum_InvalidPubKey;
    end;
  end else if (method='payloadencrypt') then begin
    // Encrypts a "payload" using "payload_method"
    // "payload_method" types: "none","pubkey"(must provide "enc_pubkey" or "b58_pubkey"),"aes"(must provide "pwd" param)
    // If payload is "pubkey"
    // Returns an hexa string with encrypted payload
    if (params.AsString('payload','')='') then begin
      ErrorNum:= CT_RPC_ErrNum_InvalidData;
      ErrorDesc := 'Need param "payload"';
      exit;
    end;
    opr.newKey := CT_TWalletKey_NUL.AccountKey;
    if (params.IndexOfName('enc_pubkey')>=0) Or (params.IndexOfName('b58_pubkey')>=0) then begin
      if Not (CapturePubKey('',opr.newKey,ErrorDesc)) then begin
        ErrorNum := CT_RPC_ErrNum_InvalidPubKey;
        exit;
      end;
    end;
    Result := DoEncrypt(TCrypto.HexaToRaw(params.AsString('payload','')),
       opr.newKey,
       params.AsString('payload_method',''),params.AsString('pwd',''));
  end else if (method='payloaddecrypt') then begin
    if (Not _RPCServer.AllowUsePrivateKeys) then begin
      // Protection when server is locked to avoid private keys call
      ErrorNum := CT_RPC_ErrNum_NotAllowedCall;
      Exit;
    end;
    // Decrypts a "payload" searching for wallet private keys and for array of strings in "pwds" param
    // Returns an JSON Object with "result" (Boolean) and
    if (params.AsString('payload','')='') then begin
      ErrorNum:= CT_RPC_ErrNum_InvalidData;
      ErrorDesc := 'Need param "payload"';
      exit;
    end;
    If Not _RPCServer.WalletKeys.IsValidPassword then begin
      ErrorNum := CT_RPC_ErrNum_WalletPasswordProtected;
      ErrorDesc := 'Wallet is password protected. Unlock first';
      exit;
    end;
    Result := DoDecrypt(TCrypto.HexaToRaw(params.AsString('payload','')),params.GetAsArray('pwds'));
  end else if (method='getconnections') then begin
    if (Not _RPCServer.AllowUsePrivateKeys) then begin
      // Protection when server is locked to avoid private keys call
      ErrorNum := CT_RPC_ErrNum_NotAllowedCall;
      Exit;
    end;
    // Returns an array of connections objects with info about state
    GetConnections;
    Result := true;
  end else if (method='addnewkey') then begin
    // Creates a new private key and stores it on the wallet, returning Public key JSON object
    // Param "ec_nid" can be 714=secp256k1 715=secp384r1 729=secp283k1 716=secp521r1. (Default = CT_Default_EC_OpenSSL_NID)
    // Param "name" is name for this address
    if (Not _RPCServer.AllowUsePrivateKeys) then begin
      // Protection when server is locked to avoid private keys call
      ErrorNum := CT_RPC_ErrNum_NotAllowedCall;
      Exit;
    end;
    If Not _RPCServer.WalletKeys.IsValidPassword then begin
      ErrorNum := CT_RPC_ErrNum_WalletPasswordProtected;
      ErrorDesc := 'Wallet is password protected. Unlock first';
      exit;
    end;
    ecpkey := TECPrivateKey.Create;
    try
      ecpkey.GenerateRandomPrivateKey(params.AsInteger('ec_nid',CT_Default_EC_OpenSSL_NID));
      _RPCServer.FWalletKeys.AddPrivateKey(params.AsString('name',DateTimeToStr(now)),ecpkey);
      TPascalCoinJSONComp.FillPublicKeyObject(ecpkey.PublicKey,GetResultObject);
      Result := true;
    finally
      ecpkey.Free;
    end;
  end else if (method='lock') then begin
    if (Not _RPCServer.AllowUsePrivateKeys) then begin
      // Protection when server is locked to avoid private keys call
      ErrorNum := CT_RPC_ErrNum_NotAllowedCall;
      Exit;
    end;
    jsonresponse.GetAsVariant('result').Value := _RPCServer.WalletKeys.LockWallet;
    Result := true;
  end else if (method='unlock') then begin
    // Unlocks the Wallet with "pwd" password
    // Returns Boolean if wallet is unlocked
    if (Not _RPCServer.AllowUsePrivateKeys) then begin
      // Protection when server is locked to avoid private keys call
      ErrorNum := CT_RPC_ErrNum_NotAllowedCall;
      Exit;
    end;
    if (params.IndexOfName('pwd')<0) then begin
      ErrorNum:= CT_RPC_ErrNum_InvalidData;
      ErrorDesc := 'Need param "pwd"';
      exit;
    end;
    If Not _RPCServer.WalletKeys.IsValidPassword then begin
      _RPCServer.WalletKeys.WalletPassword:=params.AsString('pwd','');
    end;
    jsonresponse.GetAsVariant('result').Value := _RPCServer.WalletKeys.IsValidPassword;
    Result := true;
  end else if (method='setwalletpassword') then begin
    // Changes the Wallet password with "pwd" param
    // Must be unlocked first
    // Returns Boolean if wallet password changed
    if (Not _RPCServer.AllowUsePrivateKeys) then begin
      // Protection when server is locked to avoid private keys call
      ErrorNum := CT_RPC_ErrNum_NotAllowedCall;
      Exit;
    end;
    If Not _RPCServer.WalletKeys.IsValidPassword then begin
      ErrorNum := CT_RPC_ErrNum_WalletPasswordProtected;
      ErrorDesc := 'Wallet is password protected. Unlock first';
      exit;
    end;
    //
    if (params.IndexOfName('pwd')<0) then begin
      ErrorNum:= CT_RPC_ErrNum_InvalidData;
      ErrorDesc := 'Need param "pwd"';
      exit;
    end;
    _RPCServer.WalletKeys.WalletPassword:=params.AsString('pwd','');
    jsonresponse.GetAsVariant('result').Value := _RPCServer.WalletKeys.IsValidPassword;
    Result := true;
  end else if (method='stopnode') then begin
    // Stops communications to other nodes
    if (Not _RPCServer.AllowUsePrivateKeys) then begin
      // Protection when server is locked to avoid private keys call
      ErrorNum := CT_RPC_ErrNum_NotAllowedCall;
      Exit;
    end;
    FNode.NetServer.Active := false;
    TNetData.NetData.NetConnectionsActive:=false;
    jsonresponse.GetAsVariant('result').Value := true;
    Result := true;
  end else if (method='startnode') then begin
    // Stops communications to other nodes
    if (Not _RPCServer.AllowUsePrivateKeys) then begin
      // Protection when server is locked to avoid private keys call
      ErrorNum := CT_RPC_ErrNum_NotAllowedCall;
      Exit;
    end;
    FNode.NetServer.Active := true;
    TNetData.NetData.NetConnectionsActive:=true;
    jsonresponse.GetAsVariant('result').Value := true;
    Result := true;
  end else if (method='cleanblacklist') then begin
    if (Not _RPCServer.AllowUsePrivateKeys) then begin
      // Protection when server is locked to avoid private keys call
      ErrorNum := CT_RPC_ErrNum_NotAllowedCall;
      Exit;
    end;
    jsonresponse.GetAsVariant('result').Value := TNetData.NetData.NodeServersAddresses.CleanBlackList(True);
    Result := True;
  end else if (method='node_ip_stats') then begin
    if (Not _RPCServer.AllowUsePrivateKeys) then begin
      // Protection when server is locked to avoid private keys call
      ErrorNum := CT_RPC_ErrNum_NotAllowedCall;
      Exit;
    end;
    Get_node_ip_stats;
    Result := True;
  end else begin
    LRPCProcessMethod := FindRegisteredProcessMethod(method);
    if Assigned(LRPCProcessMethod) then begin
      Result := LRPCProcessMethod(Self,method,params,jsonresponse,ErrorNum,ErrorDesc);
    end else begin
      ErrorNum := CT_RPC_ErrNum_MethodNotFound;
      ErrorDesc := 'Method not found: "'+method+'"';
    end;
  end;
end;

class procedure TRPCProcess.RegisterProcessMethod(const AMethodName: String; ARPCProcessMethod: TRPCProcessMethod);
var LRegistered : TRegisteredRPCProcessMethod;
begin
  if Not Assigned(_RPCProcessMethods) then begin
    _RPCProcessMethods := TList<TRegisteredRPCProcessMethod>.Create;
  end;
  if Assigned(FindRegisteredProcessMethod(AMethodName)) then Exit; // Duplicated!
  LRegistered.MethodName := AMethodName;
  LRegistered.RPCProcessMethod := ARPCProcessMethod;
  _RPCProcessMethods.Add(LRegistered);
end;

class procedure TRPCProcess.UnregisterProcessMethod(const AMethodName: String);
var i : Integer;
begin
  if Not Assigned(_RPCProcessMethods) then Exit;
  for i := _RPCProcessMethods.Count-1 downto 0 do begin
    if AnsiSameStr(_RPCProcessMethods.Items[i].MethodName , AMethodName) then begin
      _RPCProcessMethods.Delete(i);
    end;
  end;
end;

{ TRPCServerThread }

procedure TRPCServerThread.BCExecute;
var
  ClientSock:TSocket;
begin
  with FServerSocket do begin
    CreateSocket;
    setLinger(true,10000);
    bind('0.0.0.0',Inttostr(FPort));
    listen;
    repeat
      if terminated then break;
      Try
        if canread(1000) then begin
          ClientSock:=accept;
          if lastError=0 then begin
            TRPCProcess.create(FRPCServer,ClientSock);
          end;
        end;
      Except
        On E:Exception do begin
          TLog.NewLog(ltError,Classname,'Error '+E.ClassName+':'+E.Message);
        end;
      End;
      sleep(1);
    until false;
  end;
end;

constructor TRPCServerThread.Create(ARPCServer : TRPCServer; APort : Word);
begin
  TLog.NewLog(ltInfo,ClassName,'Activating RPC-JSON Server on port '+inttostr(APort));
  FRPCServer := ARPCServer;
  FServerSocket:=TTCPBlockSocket.create;
  FPort := APort;
  inherited create(false);
end;

destructor TRPCServerThread.Destroy;
begin
  TLog.NewLog(ltInfo,ClassName,'Stoping RPC-JSON Server');
  FreeAndNil(FServerSocket);
  inherited Destroy;
end;

procedure DoFinalize;
var i : Integer;
begin
  if Assigned(_RPCProcessMethods) then begin
    for i := _RPCProcessMethods.Count-1 downto 0 do begin
      _RPCProcessMethods.Delete(i);
    end;
  end;
  FreeAndNil(_RPCProcessMethods);
  FreeAndNil(_RPCServer);
end;

initialization
finalization
  DoFinalize;
end.
