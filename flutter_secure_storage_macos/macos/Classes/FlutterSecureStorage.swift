//
//  FlutterSecureStorage.swift
//  flutter_secure_storage_macos
//
//  Created by Julian Steenbakker on 09/12/2022.
//

import Foundation

class FlutterSecureStorage{
    
    private func baseQuery(key: String?, groupId: String?, accountName: String?, synchronizable: Bool?, returnData: Bool?, useDPK: Bool?) -> Dictionary<CFString, Any> {
        var keychainQuery: [CFString: Any] = [kSecClass : kSecClassGenericPassword]
        if (key != nil) {
            keychainQuery[kSecAttrAccount] = key
        }
        
        if (groupId != nil) {
            keychainQuery[kSecAttrAccessGroup] = groupId
        }
        
        if (accountName != nil) {
            keychainQuery[kSecAttrService] = accountName
        }
        
        if (synchronizable != nil) {
            keychainQuery[kSecAttrSynchronizable] = synchronizable
        }
        
        if (returnData != nil) {
            keychainQuery[kSecReturnData] = returnData
        }

        if #available(macOS 10.15, *) {
            if (useDPK != nil) {
                keychainQuery[kSecUseDataProtectionKeychain] = useDPK
            }
        }

        return keychainQuery
    }
    
    internal func containsKey(key: String, groupId: String?, accountName: String?, synchronizable: Bool?) -> Bool {
        if read(key: key, groupId: groupId, accountName: accountName, synchronizable: synchronizable).value != nil {
            return true
        } else {
            return false
        }
    }
    
    internal func readAll(groupId: String?, accountName: String?, synchronizable: Bool?) -> FlutterSecureStorageResponse {
        var keychainQuery = baseQuery(key: nil, groupId: groupId, accountName: accountName, synchronizable: synchronizable, returnData: true, useDPK: true)
        
        keychainQuery[kSecMatchLimit] = kSecMatchLimitAll
        keychainQuery[kSecReturnAttributes] = true
        
        var ref: AnyObject?
        let status = SecItemCopyMatching(
            keychainQuery as CFDictionary,
            &ref
        )
        
        var results: [String: String] = [:]
        
        if (status == noErr) {
            (ref as! NSArray).forEach { item in
                let key: String = (item as! NSDictionary)[kSecAttrAccount] as! String
                let value: String = String(data: (item as! NSDictionary)[kSecValueData] as! Data, encoding: .utf8) ?? ""
                results[key] = value
            }
        }
        
        return FlutterSecureStorageResponse(status: status, value: results)
    }
    
    internal func read(key: String, groupId: String?, accountName: String?, synchronizable: Bool?) -> FlutterSecureStorageResponse {
        let keychainQuery = baseQuery(key: key, groupId: groupId, accountName: accountName, synchronizable: synchronizable, returnData: true, useDPK: true)
        
        var ref: AnyObject?
        let status = SecItemCopyMatching(
            keychainQuery as CFDictionary,
            &ref
        )
        
        var value: String? = nil
        
        if (status == noErr) {
            value = String(data: ref as! Data, encoding: .utf8)
        }

        if (value == nil || status != noErr) {

            
            let keychainQuery2 = baseQuery(key: key, groupId: groupId, accountName: accountName, synchronizable: synchronizable, returnData: true, useDPK: false)


            let status2 = SecItemCopyMatching(
                keychainQuery2 as CFDictionary,
                &ref
            )

            if (status2 == noErr) {
                value = String(data: ref as! Data, encoding: .utf8)
            }
        }

        // print("reading: \(key) \(status) \(value)")
        return FlutterSecureStorageResponse(status: status, value: value)
    }
    
    internal func deleteAll(groupId: String?, accountName: String?, synchronizable: Bool?) -> OSStatus {
        let keychainQuery = baseQuery(key: nil, groupId: groupId, accountName: accountName, synchronizable: synchronizable, returnData: nil, useDPK: true)
        
        return SecItemDelete(keychainQuery as CFDictionary)
    }
    
    internal func delete(key: String, groupId: String?, accountName: String?, synchronizable: Bool?) -> OSStatus {
        let keychainQuery = baseQuery(key: key, groupId: groupId, accountName: accountName, synchronizable: synchronizable, returnData: true, useDPK: true)
        
        return SecItemDelete(keychainQuery as CFDictionary)
    }
    
    internal func write(key: String, value: String, groupId: String?, accountName: String?, synchronizable: Bool?, accessibility: String?) -> OSStatus {
        var attrAccessible: CFString = kSecAttrAccessibleWhenUnlocked
        if (accessibility != nil) {
            switch accessibility {
            case "passcode":
                attrAccessible = kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
                break;
            case "unlocked":
                attrAccessible = kSecAttrAccessibleWhenUnlocked
                break
            case "unlocked_this_device":
                attrAccessible = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
                break
            case "first_unlock":
                attrAccessible = kSecAttrAccessibleAfterFirstUnlock
                break
            case "first_unlock_this_device":
                attrAccessible = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
                break
            default:
                attrAccessible = kSecAttrAccessibleWhenUnlocked
            }
        }

        let keyExists = containsKey(key: key, groupId: groupId, accountName: accountName, synchronizable: synchronizable)
        var status: OSStatus?


        var keychainQuery = baseQuery(key: key, groupId: groupId, accountName: accountName, synchronizable: synchronizable, returnData: nil, useDPK: true)


        if (keyExists) {
            var update: [CFString: Any?] = [
                kSecValueData: value.data(using: String.Encoding.utf8),
                kSecAttrAccessible: attrAccessible,
                kSecAttrSynchronizable: synchronizable
            ]
        
            status = SecItemUpdate(keychainQuery as CFDictionary, update as CFDictionary)
        } else {
            keychainQuery[kSecValueData] = value.data(using: String.Encoding.utf8)
            keychainQuery[kSecAttrAccessible] = attrAccessible

            status = SecItemAdd(keychainQuery as CFDictionary, nil)
        }


        // try again without DPK if it failed:
        if (status != noErr) {
            var keychainQuery2 = baseQuery(key: key, groupId: groupId, accountName: accountName, synchronizable: synchronizable, returnData: nil, useDPK: false)

            if (keyExists) {
                var update: [CFString: Any?] = [
                    kSecValueData: value.data(using: String.Encoding.utf8),
                    kSecAttrAccessible: attrAccessible,
                    kSecAttrSynchronizable: synchronizable
                ]
            
                status = SecItemUpdate(keychainQuery2 as CFDictionary, update as CFDictionary)
            } else {
                keychainQuery2[kSecValueData] = value.data(using: String.Encoding.utf8)
                keychainQuery2[kSecAttrAccessible] = attrAccessible

                status = SecItemAdd(keychainQuery2 as CFDictionary, nil)
            }
        }

        
        if let error = SecCopyErrorMessageString(status!, nil) {
            print("write status: \(error) \(value)")
        }
        
        return status!
    }
    
    struct FlutterSecureStorageResponse {
        var status: OSStatus?
        var value: Any?
    }
}