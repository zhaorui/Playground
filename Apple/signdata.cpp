#include <Security/cssmtype.h>
#include <Security/cssmapi.h>
#include <Security/SecBase.h> //SecKeychainRef
#include <Security/SecKeychain.h> //SecKeychainCopySearchList
//#include <Security/SecIdentity.h> //SecIdentityCopyCertificate ????
#include <Security/SecIdentity.h>
#include <Security/SecIdentitySearch.h> 
#include <Security/SecKey.h> // SecKeyGetCSSMKey
#include <CoreFoundation/CoreFoundation.h>
#include <openssl/sha.h> //SHA1
#include <stdlib.h>
#include <iostream>
using namespace std;

//copy from TRUNK/include/darwin/secwrap.h
class CssmContext
{
    /* Cryptographic Context Handle */
    CSSM_CC_HANDLE              m_cssmContext;

public:
    CssmContext()
        : m_cssmContext(0)
    { }

    ~CssmContext()
    {
        if (m_cssmContext)
        {   
            CSSM_DeleteContext(m_cssmContext);
        }   
    }   

    CssmContext& operator=(CSSM_CC_HANDLE cssmContext)
    {   
        m_cssmContext = cssmContext;

        return *this;
    }   

    operator CSSM_CC_HANDLE()
    {   
        return m_cssmContext;
    }   

    CSSM_CC_HANDLE* operator&()
    {   
        return &m_cssmContext;
    }
};


// typedef struct cssm_data {
//  CSSM_SIZE Length;
//  uint8 *Data;
// } CSSM_DATA, *CSSM_DATA_PTR;

struct CssmData : public CSSM_DATA
{
    CssmData()
    {
        Length = 0;
        Data = 0;
    }

    ~CssmData()
    {
        if (Data)
        {
            free(Data);
        }
    }
};


int main(int argc, char ** argv)
{
    CSSM_DATA data;
    CSSM_DATA in, out;
    OSStatus ret;
    CSSM_RETURN crtn;

    // Hardcode the data
    unsigned char buffer[] = "Hello,World";
    data.Data = buffer;
    data.Length = 11;

    //Initiazlize the in
    uint8 sha1Buf[SHA_DIGEST_LENGTH];
    SHA1(data.Data, data.Length, sha1Buf);
    in.Data = sha1Buf;
    in.Length = sizeof(sha1Buf);

    //Get the KeychianRef first
    SecKeychainRef keychainRef;
    CFArrayRef keychainList;
    SecKeychainCopySearchList(&keychainList);
    CFRetain(keychainList);
    keychainRef = (SecKeychainRef) CFArrayGetValueAtIndex(keychainList, 0);

    //Get the CSP (Cryptographic Sevice Provider) Handle
    CSSM_CSP_HANDLE csp;
    ret = SecKeychainGetCSPHandle(keychainRef, &csp);
    if (ret)
    {
        cout<<"SecKeychainGetCSPHandle failed"<<endl;
        exit(-1);
    }

    //Create IdentitySearchReference
    SecIdentitySearchRef idSearch = 0;
    ret = SecIdentitySearchCreate(0, CSSM_KEYUSE_SIGN, &idSearch);
    if (ret)
    {
        cout<<"SecIdentitySearchCreate failed"<<endl;
        exit(-1);
    }

    //traverse the identities, and get cert and privateKey reference
    SecIdentityRef idRef;
    //CSSM_DATA cert;
    SecKeyRef privateKeyRef;
    while (true)
    {
        ret = SecIdentitySearchCopyNext(idSearch, &idRef);
        if (ret)
        {
            cout<<"could not find identity"<<endl;
        }
        //ret = SecIdentityCopyCertificate(idRef, &cert);
        //ret = SecIdentityCopyCertificate(idRef, &cert);
        //if (ret)
        //{
        //    cout<<"Could not copy certificate"<<endl;
        //}
        ret = SecIdentityCopyPrivateKey(idRef, &privateKeyRef);
        if (ret == noErr)
        {
            break;
        }
    }

    //Get the private key
    const CSSM_KEY *key;
    ret = SecKeyGetCSSMKey((SecKeyRef) privateKeyRef, &key);
    if (ret)
    {
        cout<<"SecKeyGetCSSMKey failed"<<endl;
        exit(-1);
    }

    //undocumented API that lets us use the key, where to use ???
    const CSSM_ACCESS_CREDENTIALS* creds;
    ret = SecKeyGetCredentials(privateKeyRef,
          CSSM_ACL_AUTHORIZATION_SIGN, kSecCredentialTypeDefault,
          &creds);
    if (ret)
    {
        cout<<"SecKeyGetCredentials failed"<<endl;
        exit(-1);
    }

    //create signature context
    CssmContext cssmContext;
    crtn = CSSM_CSP_CreateSignatureContext(csp, CSSM_ALGID_RSA, creds, key, &cssmContext);
    if (crtn)
    {
        cout<<"CSSM_CSP_CreateSignatureContext failed"<<endl;
        exit(-1);
    }

    //update padding attirbute
    CSSM_CONTEXT_ATTRIBUTE paddingAttribute;
    CSSM_PADDING padding = CSSM_PADDING_PKCS1;
    paddingAttribute.AttributeType = CSSM_ATTRIBUTE_PADDING;
    paddingAttribute.AttributeLength = sizeof(padding);
    paddingAttribute.Attribute.Data = (CSSM_DATA_PTR) padding;
    crtn = CSSM_UpdateContextAttributes(cssmContext, 1, &paddingAttribute);

    //sign the data
    crtn = CSSM_SignData(cssmContext, &in, 1, CSSM_ALGID_NONE, &out);
    if (crtn)
    {
        cout<<"CSSM_SignData failed"<<endl;
        cout<<"ErrCode: "<<hex<<crtn<<" "<<dec<<crtn<<endl;
        cssmPerror("SignData Error Message", crtn);
    }
    else
    {
        cout<<"Length: "<<out.Length<<endl;
        cout<<"Data: "<<out.Data<<endl;
    }


    CFRelease(keychainList);
    return 0;
}
