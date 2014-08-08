#include <Security/cssmtype.h>
#include <Security/cssmapi.h>
#include <Security/SecBase.h> //SecKeychainRef
#include <Security/SecKeychain.h> //SecKeychainCopySearchList
#include <Security/SecIdentitySearch.h> 
#include <CoreFoundation/CoreFoundation.h>
#include <stdlib.h>
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
    CssmContext cssmContext;
    CSSM_DATA in, out;
    OSStatus ret;

    //Get the KeychianRef first
    SecKeychainRef keychainRef;
    CFArrayRef keychainList;
    SecKeychainCopySearchList(&keychainList);
    CFRetain(keychainList);
    keychainRef = (SecKeychainRef) CFArrayGetValueAtIndex(keychainList, 0);
    
    //Get the private key
    SecIdentitySearchRef idSearch = 0;
    SecIdentityRef idRef;
    SecKeyRef privateKeyRef;
    SecCertificateRef certRef;

    ret = SecIdentitySearchCreate(0, CSSM_KEYUSE_SIGN, &idSearch);
    while (true){
        //find the specific private key?
        ret = SecIdentitySearchCopyNext(idSearch, &idRef);
        ret = SecIdentityCopyCertificate(idRef, &certRef);
        ret = SecIdentityCopyPrivateKey(idRef, &privateKeyRef);
    }



    //Get CSP Handle
    CSSM_CSP_HANDLE csp;
    ret = SecKeychainGetCSPHandle(keychainRef, &csp);
    if (ret)
    {
        cerr<<"SecKeychainGetCSPHandle failed"<<endl;
        exit(-1);
    }

    //


    //CSSM_CSP_CreateSignatureContext();
    CSSM_SignData(cssmContext, &in, 1, CSSM_ALGID_NONE, &out);


    CFRelease(keychainList);
    return 0;
}
